terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}


provider "aws" {
  region = "us-east-2"

  # Development-specific settings
  default_tags {
    tags = {
      Environment = var.env
      Project     = var.project
      Owner       = "development-team"
      CostCenter  = "dev-ops"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
  owners = ["099720109477"] # Canonical
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"
  name = "aws-rm-vpc-dev"
  cidr = "10.0.0.0/16"
  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames    = true
  tags = {
    Environment = var.env
    Name        = "${var.project}-vpc"
  }
}  

# Development-security group with conditional SSH access
resource "aws_security_group" "dev_app_server" {
  name_prefix = "dev-app-server-"
  vpc_id      = module.vpc.vpc_id
  description = "Development application server security group"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_from_anywhere ? ["0.0.0.0/0"] : ["10.0.0.0/16"]
    description = "SSH access - ${var.allow_ssh_from_anywhere ? "Open to world" : "Restricted to VPC"}"
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access for development"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access for development"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound internet access"
  }

  tags = {
    Name        = "dev-app-server-sg"
    Environment = var.env
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.dev_app_server.id]
  subnet_id              = module.vpc.private_subnets[0]
  monitoring             = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
    tags = {
      Name = "${var.instance_name}-root"
    }
  }  
  
  tags = {
    Name        = var.instance_name
    Environment = var.env
    Project     = var.project
    AutoShutdown = "true"  
    CostCenter   = "dev-123"
  }  
}

# CloudWatch alarm 
resource "aws_cloudwatch_metric_alarm" "dev_instance_down" {
  alarm_name          = "dev-app-server-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Dev instance is not running"
  actions_enabled     = false
  dimensions = {
    InstanceId = aws_instance.app_server.id
  }
}

resource "aws_ssm_association" "dev_instance_shutdown" {
  name = "AWS-StopEC2Instance"
  targets {
    key    = "InstanceIds"
    values = [aws_instance.app_server.id]
  }
  schedule_expression = "cron(0 18 ? * MON-FRI *)"
}

# Development outputs
output "dev_instance_id" {
  description = "Development instance ID"
  value       = aws_instance.app_server.id
}

output "dev_instance_public_ip" {
  description = "Development instance public IP"
  value       = aws_instance.app_server.public_ip
}

output "dev_vpc_id" {
  description = "Development VPC ID"
  value       = module.vpc.vpc_id
}

output "ssh_connection_command" {
  description = "SSH command to connect to development instance"
  value       = "ssh ubuntu@${aws_instance.app_server.public_ip}"
}

output "security_note" {
  description = "Development security note"
  value       = var.allow_ssh_from_anywhere ? "WARNING: SSH open to 0.0.0.0/0 - restrict for production!" : "SSH restricted to VPC"
}
