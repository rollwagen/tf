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


resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "my-subnet" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}
resource "aws_subnet" "my-subnet-b" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
}
resource "aws_subnet" "my-subnet-c" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-central-1c"
}

resource "aws_internet_gateway" "my-internet-gateway" {
  vpc_id = aws_vpc.my-vpc.id
}

resource "aws_route" "my-route" {
  route_table_id            = aws_vpc.my-vpc.main_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.my-internet-gateway.id
}

resource "aws_security_group_rule" "example" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_vpc.my-vpc.default_security_group_id
}
resource "aws_security_group_rule" "security_rule_http" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_vpc.my-vpc.default_security_group_id
}

resource "aws_instance" "my-ec2-instance" {
  #ami           = "ami-0b8cd61e48f1cfc2b"
  #instance_type = "t4g.micro"
  ami           = "ami-0932440befd74cdba"
  instance_type = "t2.micro"
  associate_public_ip_address = "true"
  key_name = "id_rsa.pub"
  subnet_id = aws_subnet.my-subnet.id

  user_data = <<-EOF
    #!/bin/bash
    
    apt update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y
    DEBIAN_FRONTEND=noninteractive apt install -y apache2
    echo "Hello World from $(hostname -f)" > /var/www/html/index.html

    EOF
}

output "public_ip" {
  value       = aws_instance.my-ec2-instance.public_ip
}

