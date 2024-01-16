terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "with-gpu" {
  type     = bool
  default  = false
}

resource "aws_vpc" "demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    project = "compositor-demo"
  }
}

resource "aws_subnet" "demo_public_subnet" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    project = "compositor-demo"
  }
}

resource "aws_security_group" "demo_sg" {
  name        = "demo_sg"

  ingress {
     from_port = 22
     to_port = 22
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }
  # 9000 - RTMP (input stream)
  # 9001 - HLS (output stream)
  ingress {
    from_port   = 9000
    to_port     = 9002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = aws_vpc.demo_vpc.id
  depends_on = [ aws_vpc.demo_vpc ]

  tags = {
    project = "compositor-demo"
  }
}

resource "aws_internet_gateway" "demo_ig" {
  vpc_id = aws_vpc.demo_vpc.id
  depends_on = [ aws_vpc.demo_vpc ]

  tags = {
    project = "compositor-demo"
  }
}

resource "aws_route_table" "demo_public_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_ig.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.demo_ig.id
  }

  tags = {
    project = "compositor-demo"
  }
}

resource "aws_route_table_association" "demo_public_rt_1" {
  subnet_id      = aws_subnet.demo_public_subnet.id
  route_table_id = aws_route_table.demo_public_rt.id
}

resource "aws_instance" "demo_instance" {
  # Go to "./packer" directory and run "packer build membrane.pkr.hcl" or "packer build standalone.pkr.hcl".
  # AMI of a new image will be printed at the end.
  # ami = "<ADD YOUR AMI ID HERE>"

  # g4dn.xlarge - 4vCPU + NVIDIA T4 GPU
  # c4.xlarge - CPU-only compute optimixed instance with 4 vCPU
  instance_type = var.with-gpu ? "g4dn.xlarge" : "c4.xlarge"

  subnet_id                   = aws_subnet.demo_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.demo_sg.id]
  associate_public_ip_address = true

  tags = {
    project = "compositor-demo"
  }
}

