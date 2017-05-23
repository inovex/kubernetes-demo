# Kubernetes on top of AWS

## Requirements

- `terraform` installed (tested with version `v.0.9.1` and `0.9.5`)
- `jq` installed (tested with version `jq-1.5`)
- `ansible` installed (tested with version `2.2.1.0`)
- `docker` installed (tested with version `17.03.0-ce`)
- CentOS 7 [agreement](https://aws.amazon.com/marketplace/pp/B00O7WM7QW?qid=1490197108110&sr=0-1&ref_=srh_res_product_title) for AWS in order to be able to use the AMI image

## Provision cluster

### AWS

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
