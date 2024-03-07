terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

locals {
  region="us-east-1"
  type1="t2.micro"
  type2="t2.large"
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemctl enable apache2
  sudo systemctl start apache2
  sudo chown ubuntu:ubuntu /var/www/html/index.html
  sudo echo "Hello ubuntu" > /var/www/html/index.html
  sudo -i
  mkdir scripts
  cd scripts
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  apt install unzip
  unzip awscliv2.zip
  ./aws/install
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  cp ./kubectl /usr/local/bin
  curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
  mv /tmp/eksctl /usr/local/bin
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  EOF
  
}

provider "aws" {
  region = local.region
  profile = "default"
}
/*
data "aws_iam_policy_document" "policy" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "test_role" {
  name = "EC2-ROLE-FOR-EKS-CLUSTER"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Resource = "*"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  
}



resource "aws_iam_instance_profile" "test_profile" {
  name = "test_ec2_profile"
  role = aws_iam_role.test_role.name
}
*/
data "aws_vpc" "vpc-ex" {
    filter {
      name = "vpc-id"
      values = ["vpc-04c3294be78*"]
    }
  
}

data "aws_subnet" "vpc-subnet" {
  
  filter {
    name="subnet-id"
    values = ["subnet-0c5aca*"]
  }
}

resource "aws_security_group" "newsg" {
    vpc_id = data.aws_vpc.vpc-ex.id
    name = "new-sg"
    ingress {
        description = "Allow SSH"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        from_port = 22
        to_port = 22
        
    }
    ingress {
        description = "Allow HTTP"
        from_port = 80
        to_port =  80 
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "Allow all traffic"
        from_port = 0
        to_port =  0 
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "All Outbound Traffic"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  
}

data "aws_ami" "ubuntu" {
    most_recent = true 
    
    filter {
      name = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
    }
    owners = ["099720109477"]
  
}



resource "aws_key_pair" "newkey" {
  key_name = "ec2key"
  public_key = file("ec2key.pem.pub")
}

resource "aws_instance" "main" {

  ami = data.aws_ami.ubuntu.id
  instance_type= local.type2
  subnet_id = data.aws_subnet.vpc-subnet.id
  vpc_security_group_ids = [aws_security_group.newsg.id]
  key_name = aws_key_pair.newkey.key_name
  associate_public_ip_address = true
  user_data = local.user_data
 root_block_device {
   volume_size = 30
   volume_type = "gp2"
   delete_on_termination = "true"
 }
 

  tags = {
    Name = "Demo-instance"
  }
  
  
}

output "ec2_public_ip-is" {
  value = aws_instance.main.public_ip
  
}
