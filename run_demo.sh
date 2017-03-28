#!/bin/bash

function pre_checks {
  if ! docker ps &> /dev/null; then
    echo "Docker is not running!"
    exit 1
  fi

}

function get_pub_ssh_keys {
  # Try 5 times to get each public ssh key
  #TODO ssh-keyscan really sucks -> http://unix.diviware.com/unix-page/solaris-page/solaris-man-pages/1/ssh-keyscan see exit codes
  for i in $(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.nodes.value[]')
  do
    echo "Checking SSH pub key of $i"
    ssh-keygen -R $i 2> /dev/null
    until ssh -o StrictHostKeyChecking=yes ${SSH_USER}@$i true 2> /dev/null
    do
      ssh-keyscan -T 30 -t rsa,dsa -H $i >> ~/.ssh/known_hosts
      sleep 2
    done
  done
}

function generate_certificates {
  CFSSL_VERSION=1.2.0
  echo "Update certs"
  if ! docker container run -ti -w=/certs -v $PWD/certs:/certs cfssl/cfssl:${CFSSL_VERSION} -loglevel=4 gencert -initca ca-csr.json > ./certs/tmp.json; then
    echo "Error generating certificates"
  fi

  if ! docker container run -ti --entrypoint=cfssljson -w=/certs -v $PWD/certs:/certs cfssl/cfssl:${CFSSL_VERSION} -f ./tmp.json -bare ca; then
    echo "Error generating certificates"
  fi

  if ! docker container run -ti -w=/certs -v $PWD/certs:/certs cfssl/cfssl:${CFSSL_VERSION} -loglevel=4 gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kubernetes-csr.json > ./certs/tmp.json; then
    echo "Error generating certificates"
  fi

  if ! docker container run -ti --entrypoint=cfssljson -w=/certs -v $PWD/certs:/certs cfssl/cfssl:${CFSSL_VERSION} -f ./tmp.json -bare kubernetes; then
    echo "Error generating certificates"
  fi

  echo "Validate certs"
  if ! openssl x509 -in ./certs/kubernetes.pem -text -noout > /dev/null; then
    echo 'Error validating certs'
    exit 1
  fi

  rm -rf ansible/certs && cp -r certs ansible/certs
}

function adjust_specs {
  sed -e s/REPLACE_ME/grafana.${SUB_DOMAIN}.${MAIN_DOMAIN}/g util/monitoring/ingress.yaml.sed > util/monitoring/ingress.yaml
  sed -e s/REPLACE_ME/grafana.${SUB_DOMAIN}.${MAIN_DOMAIN}/g util/monitoring/grafana.yaml.sed > util/monitoring/grafana.yaml
  sed -e s/REPLACE_ME/ui.${SUB_DOMAIN}.${MAIN_DOMAIN}/g util/dashboard/ingress.yaml.sed > util/dashboard/ingress.yaml
  sed -e s/REPLACE_ME/todo.${SUB_DOMAIN}.${MAIN_DOMAIN}/g todo-app/ingress.yaml.sed > todo-app/ingress.yaml
  sed -e s/REPLACE_ME/quobyte.${SUB_DOMAIN}.${MAIN_DOMAIN}/g quobyte/ingress.yaml.sed > quobyte/ingress.yaml
  sed -e s/REPLACE_ME/kibana.${SUB_DOMAIN}.${MAIN_DOMAIN}/g logging/ingress.yaml.sed > logging/ingress.yaml
  sed -e s/REPLACE_ME/gitlab.${SUB_DOMAIN}.${MAIN_DOMAIN}/g gitlab/ingress.yaml.sed > gitlab/ingress.yaml
  sed -e s/REPLACE_ME/quobyte.${SUB_DOMAIN}.${MAIN_DOMAIN}/g quobyte/storage-class.yaml.sed > quobyte/storage-class.yaml
}

function deploy_quobyte {
  cp -f quobyte/deployer_config.yaml.example quobyte/deployer_config.yaml
  kubectl apply -f quobyte/deployer_config.yaml
  kubectl apply -f quobyte/deployer_job.yaml

  max_waits=30
  waits=0
  until $(kubectl get job -l job-name=quobyte-deployer --no-headers -o json | jq '.items[0].status.succeeded == 1'); do
    if [[ waits -ge max_waits ]]; then
      echo "Max wait... break up"
      break
    fi

    echo "Wait for Quobyte deployment to finish"
    sleep 30
    let waits++
  done;

  # Wait a short period
  echo -n "Waiting for 90 seconds ..."
  sleep 90

  kubectl apply -f quobyte/ingress.yaml
  kubectl apply -f quobyte/storage-class.yaml
}

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -u|--user)
    SSH_USER="$2"
    shift
    ;;
    -p|--pub_key)
    PUB_KEY="$2"
    shift
    ;;
    -m|--main_domain)
    MAIN_DOMAIN="$2"
    shift
    ;;
    -s|--sub_domain)
    SUB_DOMAIN="$2"
    shift
    ;;
    -mi|--main_domain_id)
    MAIN_DOMAIN_ID="$2"
    shift
    ;;
    -d|--delete)
    DELETE="aws"
    shift
    ;;
    -n|--nodes)
    NODES="$2"
    shift
    ;;
    *)
    echo "Unkown argument ${key}"
    ;;
esac
shift
done

# TODO can be an invalid name
SUB_DOMAIN=${SUB_DOMAIN:-"$(logname)"}
MAIN_DOMAIN=${MAIN_DOMAIN:-"aws.inovex.io"}

# Move this into tfvar file?
export TF_VAR_user=$(logname)
export TF_VAR_node_count=${NODES:-"3"}
export TF_VAR_ssh_pub_key=$(cat "${PUB_KEY:-"$HOME/.ssh/id_rsa.pub"}")
export TF_VAR_main_domain=${MAIN_DOMAIN}
export TF_VAR_main_domain_id=${MAIN_DOMAIN_ID:-"XXXXX"}
export TF_VAR_sub_domain=${SUB_DOMAIN}

if [[ ! -z "${DELETE}" ]]; then
  echo "Delete AWS Cluster"
  if ! terraform destroy -force -state=terraform/aws/terraform.tfstate terraform/aws &> ./terraform.log ; then
    echo 'Something went wrong plese check "terraform plan"'
    exit 1
  fi
  exit
fi

echo "Execute terraform plan"
if ! terraform plan -state=terraform/aws/terraform.tfstate terraform/aws &> ./terraform.log ; then
  echo 'Something went wrong plese check "terraform plan"'
  exit 1
fi

echo "Execute terraform apply"
if ! terraform apply -state=terraform/aws/terraform.tfstate terraform/aws &> ./terraform.log ; then
  echo 'Something went wrong plese check "terraform apply"'
  exit 1
fi

sleep 30
echo "Creating Ansible Inventory"
SSH_USER=${SSH_USER:-"centos"}
#TODO copy the Ansible variable file and adjust the component versions if needed
cp ansible/group_vars/all.example ansible/group_vars/all
echo -e "[kubernetes-master]\n$(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.master.value')" > ansible/inventory
echo -e "[kubernetes-nodes]\n$(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.nodes.value[]')" >> ansible/inventory
echo -e "[all:vars]\nansible_ssh_user=${SSH_USER}" >> ansible/inventory

get_pub_ssh_keys

cat certs/kubernetes-csr.json.example | jq -r --argjson nodes "$(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.nodes.value')" '.hosts |= .+ $nodes' > certs/kubernetes-csr_without_private.json
cat certs/kubernetes-csr_without_private.json | jq -r --argjson nodes "$(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.private_ips.value')" '.hosts |= .+ $nodes' > certs/kubernetes-csr.json
rm -f certs/kubernetes-csr_without_private.json

if [[ $(wc -l ansible/group_vars/all | awk {'print $4"  "$1'}) -ne "$(wc -l ansible/group_vars/all.example | awk {'print $4"  "$1'})" ]]; then
  echo "Found difference in line numbers for ansible/group_vars/all and ansible/group_vars/all.example"
  diff ansible/group_vars/all ansible/group_vars/all.example
  exit
fi

sed -i '' "s/.*etcd_host: .*/etcd_host: $(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.master_private.value')/" ansible/group_vars/all
sed -i '' "s/.*kubernetes_master: .*/kubernetes_master: $(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.master_private.value')/" ansible/group_vars/all
sed -i '' "s/.*kubelet_use_ipv4: .*/kubelet_use_ipv4: true/" ansible/group_vars/all
TOKEN="$(openssl rand -base64 32)"
until sed -i '' "s/.*kubernetes_token_pw: .*/kubernetes_token_pw: ${TOKEN}/" ansible/group_vars/all; do
  TOKEN="$(openssl rand -base64 32)"
done
cat ansible/group_vars/all

if ! ansible all -m ping -i ansible/inventory; then
  echo 'Some nodes are not responding'
  exit 1
fi

generate_certificates

echo "Staring deployment"
ansible-playbook -i ansible/inventory ansible/site.yml

echo "Adjust ingress names to match doman: ${SUB_DOMAIN}.${MAIN_DOMAIN}"
adjust_specs

echo "Deploy kubernetes addons DNS, Dashboard"
kubectl config set-cluster k8s-demo-cluster --certificate-authority=certs/ca.pem --embed-certs=true --server=https://$(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.master.value'):6443
kubectl config set-credentials admin --token ${TOKEN}
kubectl config set-context default-context --cluster=k8s-demo-cluster --user=admin
kubectl config use-context default-context
kubectl get componentstatuses

for i in $(terraform output -state=terraform/aws/terraform.tfstate -json | jq -r '.frontend.value[]');
do
  echo "Label Frontend $i as fronted"
  kubectl label node $i frontend=true
done

echo "Deploy INGRESS"
BASIC_PASSWORD="$(openssl rand -base64 32)"
htpasswd -cb auth inovex ${BASIC_PASSWORD}
kubectl -n kube-system create secret generic basic-auth --from-file=auth
rm -f auth
kubectl create -f ingress/
kubectl create -f util/dns.yaml
kubectl create -f util/dashboard
kubectl create -f util/node-problem-detector.yaml

echo "Deploy Quobyte on Kubernetes"
deploy_quobyte

echo "Create Dashboard configs"
kubectl create namespace monitoring &> /dev/null
kubectl create -n monitoring configmap grafana-config --from-file=util/monitoring/dashboards/grafana-source.json
kubectl create -n monitoring configmap dashboards \
        --from-file=util/monitoring/dashboards/todo_app.json \
        --from-file=util/monitoring/dashboards/redis.json \
        --from-file=util/monitoring/dashboards/quobyte-dashboard.json \
        --from-file=util/monitoring/dashboards/kubernetes-dashboard.json

echo "Deploy Monitoring"
kubectl create -f util/monitoring

echo "Deploy Logging"
kubectl create -f logging

echo "Deploy Gitlab"
kubectl create namespace gitlab &> /dev/null
kubectl create -f gitlab

echo "Kubernetes Dashboard: http://ui.${SUB_DOMAIN}.${MAIN_DOMAIN}"
echo "Grafana    Dashboard: http://grafana.${SUB_DOMAIN}.${MAIN_DOMAIN}"
echo "Gitlab     Dashboard: http://gitlab.${SUB_DOMAIN}.${MAIN_DOMAIN}"
echo "Quobyte    Dashboard: http://quobyte.${SUB_DOMAIN}.${MAIN_DOMAIN}"
echo "Todo App   Dashboard: http://todo.${SUB_DOMAIN}.${MAIN_DOMAIN}"
echo "Kibana     Dashboard: http://kibana.${SUB_DOMAIN}.${MAIN_DOMAIN}"
echo ""
echo "Password for Kibana and Kubernetes UI:"
echo "           user: inovex"
echo "           password: ${BASIC_PASSWORD}"
echo ""
echo "Token for Kubernetes cluster:"
echo "           user: admin"
echo "           token: ${TOKEN}"
echo ""
echo "Password for Quobyte:"
echo "           user: admin"
echo "           password: quobyte"
echo ""
echo "Password for Grafana:"
echo "           user: admin"
echo "           password: PASSWORD"
echo ""
echo "Run \"kubectl create -f todo-app\" to deploy the demo application"
