# Configure the Amazon AWS Provider
provider "aws" {
  # assume_role {
  #   role_arn = var.aws_assume_role_arn
  # }

  # profile                 = var.aws_profile
  # shared_credentials_file = var.aws_cred_file
  region  = var.aws_region
  version = "~> 2.44"
}

provider "template" {
  version = "~> 2.1"
}

variable "aws_assume_role_arn" {
}

variable "aws_profile" {
}

variable "aws_cred_file" {
}

variable "vpc_id" {
}

variable "vpc_cidr" {
}

variable "public_subnet" {
}

variable "ssh_cidr_range" {
}

variable "prefix" {
  default     = "yourname"
  description = "Cluster Prefix - All resources created by Terraform have this prefix prepended to them"
}

variable "rancher_version" {
  default     = "latest"
  description = "Rancher Server Version"
}

variable "count_agent_all_nodes" {
  default     = "1"
  description = "Number of Agent All Designation Nodes"
}

variable "count_agent_etcd_nodes" {
  default     = "0"
  description = "Number of ETCD Nodes"
}

variable "count_agent_controlplane_nodes" {
  default     = "0"
  description = "Number of K8s Control Plane Nodes"
}

variable "count_agent_worker_nodes" {
  default     = "0"
  description = "Number of Worker Nodes"
}

variable "admin_password" {
  default     = "admin"
  description = "Password to set for the admin account in Rancher"
}

variable "cluster_name" {
  default     = "quickstart"
  description = "Kubernetes Cluster Name"
}

variable "aws_region" {
  default     = "us-west-2"
  description = "Amazon AWS Region for deployment"
}

variable "type" {
  default     = "t3.medium"
  description = "Amazon AWS Instance Type"
}

variable "docker_version_server" {
  default     = "19.03"
  description = "Docker Version to run on Rancher Server"
}

variable "docker_version_agent" {
  default     = "19.03"
  description = "Docker Version to run on Kubernetes Nodes"
}

variable "ssh_key_name" {
  default     = ""
  description = "Amazon AWS Key Pair Name"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "rancher_sg_allowall" {
  name        = "${var.prefix}-rancher-allowall"
  description = "${var.prefix}-rancher-allowall"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr_range]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-rancher-allowall_sg"
  }
}

data "template_cloudinit_config" "rancherserver-cloudinit" {
  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancherserver\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.userdata_server.rendered
  }
}

resource "aws_instance" "rancherserver" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = var.public_subnet
  associate_public_ip_address = "true"
  user_data                   = data.template_cloudinit_config.rancherserver-cloudinit.rendered

  tags = {
    Name = "${var.prefix}-rancherserver"
  }
}

data "template_cloudinit_config" "rancheragent-all-cloudinit" {
  count = var.count_agent_all_nodes

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-all\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.userdata_agent.rendered
  }
}

resource "aws_instance" "rancheragent-all" {
  count                       = var.count_agent_all_nodes
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = var.public_subnet
  associate_public_ip_address = "true"
  user_data                   = data.template_cloudinit_config.rancheragent-all-cloudinit[count.index].rendered

  tags = {
    Name = "${var.prefix}-rancheragent-${count.index}-all"
  }
}

data "template_cloudinit_config" "rancheragent-etcd-cloudinit" {
  count = var.count_agent_etcd_nodes

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-etcd\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.userdata_agent.rendered
  }
}

resource "aws_instance" "rancheragent-etcd" {
  count                       = var.count_agent_etcd_nodes
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = var.public_subnet
  associate_public_ip_address = "true"
  user_data                   = data.template_cloudinit_config.rancheragent-etcd-cloudinit[count.index].rendered

  tags = {
    Name = "${var.prefix}-rancheragent-${count.index}-etcd"
  }
}

data "template_cloudinit_config" "rancheragent-controlplane-cloudinit" {
  count = var.count_agent_controlplane_nodes

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-controlplane\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.userdata_agent.rendered
  }
}

resource "aws_instance" "rancheragent-controlplane" {
  count                       = var.count_agent_controlplane_nodes
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = var.public_subnet
  associate_public_ip_address = "true"
  user_data                   = data.template_cloudinit_config.rancheragent-controlplane-cloudinit[count.index].rendered

  tags = {
    Name = "${var.prefix}-rancheragent-${count.index}-controlplane"
  }
}

data "template_cloudinit_config" "rancheragent-worker-cloudinit" {
  count = var.count_agent_worker_nodes

  part {
    content_type = "text/cloud-config"
    content      = "hostname: ${var.prefix}-rancheragent-${count.index}-worker\nmanage_etc_hosts: true"
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.userdata_agent.rendered
  }
}

resource "aws_instance" "rancheragent-worker" {
  count                       = var.count_agent_worker_nodes
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = var.public_subnet
  associate_public_ip_address = "true"
  user_data                   = data.template_cloudinit_config.rancheragent-worker-cloudinit[count.index].rendered

  tags = {
    Name = "${var.prefix}-rancheragent-${count.index}-worker"
  }
}

data "template_file" "userdata_server" {
  template = file("files/userdata_server")

  vars = {
    admin_password        = var.admin_password
    cluster_name          = var.cluster_name
    docker_version_server = var.docker_version_server
    rancher_version       = var.rancher_version
  }
}

data "template_file" "userdata_agent" {
  template = file("files/userdata_agent")

  vars = {
    admin_password       = var.admin_password
    cluster_name         = var.cluster_name
    docker_version_agent = var.docker_version_agent
    rancher_version      = var.rancher_version
    server_address       = aws_instance.rancherserver.public_ip
  }
}

output "rancher-url" {
  value = ["https://${aws_instance.rancherserver.public_ip}"]
}

