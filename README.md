# Kubernetes on top of AWS

## Requirements

- `terraform` installed (tested `v.0.9.1`)
- `jq` installed (tested `jq-1.5`)
- `ansible` installed (tested `2.2.1.0`)
- `docker` installed (tested `17.03.0-ce`)
- CentOS 7 [agreement](https://aws.amazon.com/marketplace/pp/B00O7WM7QW?qid=1490197108110&sr=0-1&ref_=srh_res_product_title) for AWS

## Provision cluster

### AWS

Terraform is installed and configured with an AWS account


$ Set AWS variables in

```bash

$ vim terraform/aws/variables.tf
```

```bash
$ ./run_demo.sh -u <AMI IMAGE USER> -p <ssh pub key which should be injected> -s "<subdomain> " -m "<main domain>" -mi "<ROUTE53 domain id>" -n <number of instances>
```

e.g.

```bash
$ ./run_demo.sh -u centos -p $HOME/.ssh/id_rsa.pub -s "test" -m "aws.domain.org" -mi "Z234SFHJS" -n 10
```

## Delete Cluster

### AWS

```bash
./run_demo.sh -d aws
```
