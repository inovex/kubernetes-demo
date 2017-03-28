variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "eu-central-1"
}

variable "ssh_pub_key" {
  description = "ssh pub key"
  default     = ""
}

variable "user" {
    default = "inovex"
}

variable "node_count" {
    default = 5
}

variable "main_domain" {
    default = "domain.org"
}

variable "main_domain_id" {
    default = "XXX"
}

variable "sub_domain" {
    default = "k8s"
}

variable "instance_type" {
    default = "t2.2xlarge"
}
