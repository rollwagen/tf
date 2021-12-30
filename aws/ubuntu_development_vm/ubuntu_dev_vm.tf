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
  type        = string
  default     = "0.0.0.0/0"
  description = "IP address (CIDR) to restrict ssh and mosh inbound traffic to."
}


resource "aws_vpc" "dev-vpc" {
  #ts:skip=AWS.VPC.Logging.Medium.0470 Just 'play'/short lived VM
  #checkov:skip=BC_AWS_LOGGING_9:Just 'play'/short lived VM
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "my-subnet" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}
resource "aws_subnet" "my-subnet-b" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
}
resource "aws_subnet" "my-subnet-c" {
  vpc_id            = aws_vpc.dev-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-central-1c"
}

resource "aws_internet_gateway" "my-internet-gateway" {
  vpc_id = aws_vpc.dev-vpc.id
}

resource "aws_route" "my-route" {
  route_table_id         = aws_vpc.dev-vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my-internet-gateway.id
}

resource "aws_security_group_rule" "sg-rule-ssh-inbound" {
  type              = "ingress"
  cidr_blocks       = [var.sg_inbound_ip]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_vpc.dev-vpc.default_security_group_id
}

/*
resource "aws_security_group_rule" "sg-rule-elasticsearch-inbound" {
  type              = "ingress"
  cidr_blocks       = [var.sg_inbound_ip]
  from_port         = 9200
  to_port           = 9200
  protocol          = "tcp"
  security_group_id = aws_vpc.dev-vpc.default_security_group_id
}
*/



resource "aws_security_group_rule" "sg-rule-mosh-inbound" {
  type              = "ingress"
  cidr_blocks       = [var.sg_inbound_ip]
  from_port         = 60000
  to_port           = 61000
  protocol          = "udp"
  security_group_id = aws_vpc.dev-vpc.default_security_group_id
}

resource "aws_instance" "my-ec2-instance" {
  #ts:skip=AWS.CloudTrail.Logging.Medium.008 Dev resp. play short lived instance
  #ts:skip=AC-AW-IS-IN-M-0144 Default VPC is fine for this
  #ts:skip=AC_AWS_070 "No detailed monitoring required"
  ami           = "ami-0b8cd61e48f1cfc2b"
  instance_type = "t4g.medium"
  #instance_type = "t4g.micro"
  #ami           = "ami-0932440befd74cdba"
  #instance_type = "t2.micro"
  associate_public_ip_address = "true"
  key_name                    = "id_rsa.pub"
  #checkov:skip=CKV_AWS_88:This instance requires a public IP (direct SSH access)
  subnet_id = aws_subnet.my-subnet.id
  root_block_device { encrypted = "true" }
  monitoring = "true"
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash

    apt update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y
    DEBIAN_FRONTEND=noninteractive apt install -y gnupg software-properties-common curl locales gcc
    DEBIAN_FRONTEND=noninteractive apt install -y neovim netcat shellcheck fd-find net-tools
    DEBIAN_FRONTEND=noninteractive apt install -y nmap mosh rsync fzf zsh zsh-syntax-highlighting unzip jq docker.io

    sudo usermod -aG docker ubuntu

    if [[ $(dpkg --print-architecture) != "arm64" ]]
    then
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
      sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
      sudo apt update
      DEBIAN_FRONTEND=noninteractive apt install -y terraform
    fi

    curl "https://awscli.amazonaws.com/awscli-exe-linux-`uname -m`.zip" -o "/tmp/awscliv2.zip"
    unzip -q -d /tmp/ /tmp/awscliv2.zip
    sudo /tmp/aws/install
    rm -rf /tmp/aws*
    echo 'complete -C "/usr/local/bin/aws_completer" aws' >> "/home/ubuntu/.bashrc"
    [ -d "/home/ubuntu/.aws" ] || mkdir "/home/ubuntu/.aws"
    echo -e "[default]\ncli_pager=jq\noutput=json\nregion=eu-central-1" > "/home/ubuntu/.aws/config"

    # for mosh to work properly
    sudo locale-gen "en_US.UTF-8"
    sudo update-locale LC_ALL="en_US.UTF-8"

    # lsd and bat
    curl -OL https://github.com/Peltoche/lsd/releases/download/0.20.1/lsd_0.20.1_$(dpkg --print-architecture).deb
    sudo dpkg -i lsd_*.deb
    curl -OL https://github.com/sharkdp/bat/releases/download/v0.18.3/bat_0.18.3_$(dpkg --print-architecture).deb
    sudo dpkg -i bat_*.deb
    rm ./*.deb


    EOF
}

output "public_ip" {
  value       = aws_instance.my-ec2-instance.public_ip
  description = "Public IP of the created instance."
}
