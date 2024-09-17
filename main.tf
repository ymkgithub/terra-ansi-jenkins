terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "mahesh-cw-todo-app"
    key = "backend/tf-backend-jenkins.tfstate"
    region = "us-west-2"
    
  }
}

provider "aws" {
  region = local.region
}

# resource "aws_iam_role" "aws_access" {
#   name = "${var.prefix}-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Sid    = ""
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
#   managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"]
# }

# resource "aws_iam_instance_profile" "instance_profile" {
#   name = "${var.prefix}-profile"
#   role = aws_iam_role.aws_access.name
# }

# Get the latest Amazon Linux 2 AMI with gp2
data "aws_ami" "amazon_linux_free_tier" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]  # Only AMIs owned by Amazon
}

resource "aws_instance" "managed_nodes" {
  ami = data.aws_ami.amazon_linux_free_tier.id
  count = 3
  instance_type = "t2.micro"
  key_name = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.sg.id]
  # iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  tags = {
    Name        = "${element(var.names, count.index)}"
    stack       = var.prefix
    environment = "development"
  }
}

resource "aws_security_group" "sg" {
  name = "${var.prefix}-sg"

  dynamic "ingress" {
    for_each = local.ingress_ports
    iterator = port
    content {
      from_port   = port.value
      protocol    = "tcp"
      to_port     = port.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}