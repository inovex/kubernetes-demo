# Kubernetes on top of AWS

## Requirements

- `terraform` installed (tested with version `v.0.9.1` and `0.9.5`)
- `jq` installed (tested with version `jq-1.5`)
- `ansible` installed (tested with version `2.2.1.0`)
- `docker` installed (tested with version `17.03.0-ce`)
- CentOS 7 [agreement](https://aws.amazon.com/marketplace/pp/B00O7WM7QW?qid=1490197108110&sr=0-1&ref_=srh_res_product_title) for AWS in order to be able to use the AMI image

## Provision cluster

### AWS
#### Create a route53 domain for your cluster
(taken from https://kubernetes.io/docs/getting-started-guides/kops/)
You can, and probably should, use subdomains to divide your clusters. As our example we will use useast1.dev.example.com. The API server endpoint will then be api.useast1.dev.example.com.
A Route53 hosted zone can serve subdomains. Your hosted zone could be useast1.dev.example.com, but also dev.example.com or even example.com. kops works with any of these, so typically you choose for organization reasons (e.g. you are allowed to create records under dev.example.com, but not under example.com).
Let’s assume you’re using dev.example.com as your hosted zone. You create that hosted zone using the normal process, or with a command such as aws route53 create-hosted-zone --name dev.example.com --caller-reference 1.
You must then set up your NS records in the parent domain, so that records in the domain will resolve. Here, you would create NS records in example.com for dev. If it is a root domain name you would configure the NS records at your domain registrar (e.g. example.com would need to be configured where you bought example.com).
This step is easy to mess up (it is the #1 cause of problems!) You can double-check that your cluster is configured correctly if you have the dig tool by running:
dig NS dev.example.com
You should see the 4 NS records that Route53 assigned your hosted zone.

#### Starting up the demo
Terraform is installed and configured with an AWS account. (using `~/.aws/credentials` is sufficient)

$ Set AWS variables in

```bash
$ vim terraform/aws/variables.tf
```

if needed. Most of them can be overridden via the command line.

```bash
$ ./run_demo.sh -u <AMI IMAGE USER> -p <ssh pub key> -s "<subdomain> " -m "<main domain>" -mi "<ROUTE53 domain id of main domain>" -n <number of instances>
```

- **-u AMI IMAGE USER** will be the user used for the deployment of k8s. You'll have to use the one provided by the Image you chose. ("centos" if you use the proposed image)
- **-p ssh pub key** is the pub key which will be used to authenticate the user above
- **-m main domain** is the name of the domain that will be used to attach the below above to, e.g. if `aws.demo.com` is the main domain and `k8s` is used as subdomain, the DNS records for the services will be created als `grafana.k8s.aws.demo.com` or `ui.k8s.aws.demo.com`. This domain needs to be pre-provisioned and a delegation needs to be set up.
- **-s subdomain** is the subdomain being attached. See above
- **-mi ROUTE53 domain id of main domain** is the ID of the main domain to attach to. You can obtain this value via the Amazon Route53 Dashboard.
- **-n number of instances** adjusts the size of the cluster. You will end up with 1 controller and `(n-1)` nodes, so setting this below 3 will not leave much of a cluster.

e.g.

```bash
$ ./run_demo.sh -u centos -p $HOME/.ssh/id_rsa.pub -s "k8s" -m "aws.demo.com" -mi "Z234SFHJS" -n 10
```

Spawning a cluster will take about 12 minutes, including all the services.

## Delete Cluster

### AWS

```bash
./run_demo.sh -d aws
```
