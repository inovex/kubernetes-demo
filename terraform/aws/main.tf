provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_vpc" "kubernetes" {
  cidr_block = "10.241.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags {
    Name = "kubernetes"
    User = "${var.user}"
  }
}

resource "aws_vpc_dhcp_options" "kubernetes_dhcp" {
    domain_name = "eu-central-1.compute.internal"
    domain_name_servers = ["AmazonProvidedDNS"]

    tags {
        Name = "kubernetes"
        User = "${var.user}"
    }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
    vpc_id = "${aws_vpc.kubernetes.id}"
    dhcp_options_id = "${aws_vpc_dhcp_options.kubernetes_dhcp.id}"
}

resource "aws_subnet" "kubernetes_subnet" {
    vpc_id = "${aws_vpc.kubernetes.id}"

    cidr_block = "10.241.0.0/24"

    tags {
        Name = "kubernetes"
        User = "${var.user}"
    }
}

resource "aws_internet_gateway" "kubernetes_gw" {
    vpc_id = "${aws_vpc.kubernetes.id}"

    tags {
        Name = "kubernetes"
        User = "${var.user}"
    }
}

resource "aws_route_table" "kubernetes_route_table" {
    vpc_id = "${aws_vpc.kubernetes.id}"

    route {
        cidr_block = "10.0.1.0/24"
        gateway_id = "${aws_internet_gateway.kubernetes_gw.id}"
    }

    tags {
        Name = "kubernetes"
        User = "${var.user}"
    }
}

resource "aws_route_table_association" "route_assoc" {
    subnet_id = "${aws_subnet.kubernetes_subnet.id}"
    route_table_id = "${aws_route_table.kubernetes_route_table.id}"
}

resource "aws_route" "route" {
    route_table_id =  "${aws_route_table.kubernetes_route_table.id}"
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.kubernetes_gw.id}"
}

resource "aws_security_group" "kubernetes_sg" {
  name = "kubernetes-${var.user}"
  description = "Kubernetes security group"
  vpc_id = "${aws_vpc.kubernetes.id}"

  tags {
      Name = "kubernetes"
      User = "${var.user}"
  }
}

resource "aws_security_group_rule" "allow_all_internal" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["10.241.0.0/16"]

    security_group_id = "${aws_security_group.kubernetes_sg.id}"
}

resource "aws_security_group_rule" "allow_ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = "${aws_security_group.kubernetes_sg.id}"
}

resource "aws_security_group_rule" "allow_http" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = "${aws_security_group.kubernetes_sg.id}"
}

resource "aws_security_group_rule" "allow_https" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = "${aws_security_group.kubernetes_sg.id}"
}

resource "aws_security_group_rule" "allow_apis" {
    type = "ingress"
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    security_group_id = "${aws_security_group.kubernetes_sg.id}"
}

resource "aws_security_group_rule" "allow_all_in_group" {
    type = "ingress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    source_security_group_id  = "${aws_security_group.kubernetes_sg.id}"
    security_group_id = "${aws_security_group.kubernetes_sg.id}"
}


resource "aws_security_group_rule" "allow_outbound" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.kubernetes_sg.id}"
}

resource "aws_iam_role" "kubernetes" {
    name = "kubernetes${var.user}"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "kubernetes" {
    name = "kubernetes-${var.user}"
    role = "${aws_iam_role.kubernetes.name}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": ["ec2:*"], "Resource": ["*"]},
    {"Effect": "Allow", "Action": ["elasticloadbalancing:*"], "Resource": ["*"]},
    {"Effect": "Allow", "Action": ["route53:*"], "Resource": ["*"]},
    {"Effect": "Allow", "Action": ["ecr:*"], "Resource": "*"}
  ]
}
EOF
}

resource "aws_iam_instance_profile" "kubernetes" {
  name = "kubernetes-${var.user}"
  roles = ["${aws_iam_role.kubernetes.name}"]
}

resource "aws_key_pair" "kubernetes" {
  key_name = "kubernetes-${var.user}"
  public_key = "${var.ssh_pub_key}"
}

resource "aws_instance" "node" {
  count = "${var.node_count}"
  ami = "ami-9bf712f4"
  key_name = "${aws_key_pair.kubernetes.key_name}"
  instance_type = "${var.instance_type}"
  vpc_security_group_ids = ["${aws_security_group.kubernetes_sg.id}"]
  subnet_id = "${aws_subnet.kubernetes_subnet.id}"
  iam_instance_profile = "${aws_iam_instance_profile.kubernetes.id}"
  associate_public_ip_address = true
  private_ip = "10.241.0.${count.index + 4}"
  source_dest_check = false

  tags {
    Name = "Node"
    User = "${var.user}"
  }
}

# TODO generate Sub DNS Zone ?
resource "aws_route53_zone" "kubernetes" {
   name = "${var.sub_domain}.${var.main_domain}"

   tags {
     Name = "kubernetes"
     User = "${var.user}"
   }
}

resource "aws_route53_record" "kubernetes" {
  zone_id = "${var.main_domain_id}" # Reference to main domain
  name = "${var.sub_domain}.${var.main_domain}"
  type = "NS"
  ttl = "30"
  records = [
      "${aws_route53_zone.kubernetes.name_servers.0}",
      "${aws_route53_zone.kubernetes.name_servers.1}",
      "${aws_route53_zone.kubernetes.name_servers.2}",
      "${aws_route53_zone.kubernetes.name_servers.3}"
  ]
}

resource "aws_route53_record" "grafana" {
  zone_id = "${aws_route53_zone.kubernetes.zone_id}"
  name = "grafana.${var.sub_domain}.${var.main_domain}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.node.0.public_ip}"]
}

resource "aws_route53_record" "gitlab" {
  zone_id = "${aws_route53_zone.kubernetes.zone_id}"
  name = "gitlab.${var.sub_domain}.${var.main_domain}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.node.0.public_ip}"]
}

resource "aws_route53_record" "quobyte" {
  zone_id = "${aws_route53_zone.kubernetes.zone_id}"
  name = "quobyte.${var.sub_domain}.${var.main_domain}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.node.0.public_ip}"]
}

resource "aws_route53_record" "ui" {
  zone_id = "${aws_route53_zone.kubernetes.zone_id}"
  name = "ui.${var.sub_domain}.${var.main_domain}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.node.0.public_ip}"]
}

resource "aws_route53_record" "todo" {
  zone_id = "${aws_route53_zone.kubernetes.zone_id}"
  name = "todo.${var.sub_domain}.${var.main_domain}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.node.0.public_ip}"]
}

resource "aws_route53_record" "kibana" {
  zone_id = "${aws_route53_zone.kubernetes.zone_id}"
  name = "kibana.${var.sub_domain}.${var.main_domain}"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.node.0.public_ip}"]
}

output "master" {
  value = "${aws_instance.node.1.public_ip}"
}

output "master_private" {
  value = "${aws_instance.node.1.private_ip}"
}

output "nodes" {
  value = [
    "${aws_instance.node.*.public_ip}",
  ]
}

output "private_ips" {
  value = [
    "${aws_instance.node.*.private_ip}",
  ]
}

output "frontend" {
  value = [
    "${aws_instance.node.0.private_ip}"
  ]
}
