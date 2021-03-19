terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region                  = "eu-central-1"
  shared_credentials_file = "~/.aws/credentials"
}

# export TF_VAR_sg_inbound_ip=`curl 'https://api.ipify.org?format=text'`/32
variable "sg_inbound_ip" {
  type    = string
  default = "0.0.0.0/0" 
}


resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "my-subnet" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}
resource "aws_subnet" "my-subnet-b" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
}
resource "aws_subnet" "my-subnet-c" {
  vpc_id     = aws_vpc.dev-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-central-1c"
}

resource "aws_internet_gateway" "my-internet-gateway" {
  vpc_id = aws_vpc.dev-vpc.id
}

resource "aws_route" "my-route" {
  route_table_id            = aws_vpc.dev-vpc.main_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.my-internet-gateway.id
}

resource "aws_security_group_rule" "example" {
  type              = "ingress"
  cidr_blocks       = [var.sg_inbound_ip]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_vpc.dev-vpc.default_security_group_id
}

resource "aws_instance" "my-ec2-instance" {
  #ami           = "ami-0b8cd61e48f1cfc2b"
  #instance_type = "t4g.micro"
  ami           = "ami-0932440befd74cdba"
  instance_type = "t2.micro"
  associate_public_ip_address = "true"
  key_name = "id_rsa.pub"
  #bridgecrew:skip=CKV_AWS_88:This instance requires a public IP (direct SSH access)
  subnet_id = aws_subnet.my-subnet.id
  root_block_device { encrypted = "true" }
  metadata_options {
	http_tokens = "required"
	http_endpoint = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash
    
    apt update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y
    DEBIAN_FRONTEND=noninteractive apt install -y nmap mosh

    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    DEBIAN_FRONTEND=noninteractive apt install -y terraform

    EOF
}

output "public_ip" {
  value       = aws_instance.my-ec2-instance.public_ip
}

