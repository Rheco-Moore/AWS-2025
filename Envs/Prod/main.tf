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

  owners = ["099720109477"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "${var.project}-${var.env}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "app_server" {
  name_prefix = "app-server-"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]  # SSH only from my IP
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_server.id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = {
    Name = var.instance_name
  }
}

# CloudWatch alarm with proper configuration
resource "aws_cloudwatch_metric_alarm" "dev_instance_down" {
  alarm_name          = "dev-app-server-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Development instance is not running"
  actions_enabled     = false 
  dimensions = {
    InstanceId = aws_instance.app_server.id
  }
}



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
  value       = "ssh ubuntu@${aws_instance.app_server.public_ip}"  # ✅ FIXED: Removed backslash
}

output "security_note" {
  description = "Development security note"
  value       = var.allow_ssh_from_anywhere ? "WARNING: SSH open to 0.0.0.0/0 - restrict for production!" : "SSH restricted to VPC"
}

# IAM role
resource "aws_iam_role" "lambda_exec" {
  name = "web_app_lambda_exec"
   assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_access" {
  name        = "lambda_s3_access"
  description = "Allows Lambda to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-terraform-state-bucket-us-east-2",
          "arn:aws:s3:::my-terraform-state-bucket-us-east-2/*"
        ]
      }
    ]
  })
}


# Logging permissions
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.s3_access.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "index.mjs"          
  output_path = "lambda_api.zip"     
}  

resource "aws_lambda_function" "web_app" {
  function_name = "${var.project}-${var.env}-web-app"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  timeout       = 30
  memory_size   = 128
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  architectures = ["arm64"]
  
  environment {
    variables = {
      ENVIRONMENT = var.env
      PROJECT     = var.project
    }
  }
}


# HTTP API Gateway 
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project}-${var.env}-http_api"
  protocol_type = "HTTP"
}
# API Gateway Integration Dependency
resource "aws_apigatewayv2_integration" "lambda_integration" {
  depends_on = [aws_lambda_function.web_app]
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.web_app.invoke_arn
  integration_method = "POST"
}
# lambda permissions
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web_app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# PROXY
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Staging
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# AWS_S3_bucket for frontend
resource "aws_s3_bucket" "frontend" {
  bucket   = "${var.frontend_bucket_name}-${random_string.suffix.id}"
  force_destroy = true
  
  tags = {
    Name = "web-frontend"
    Environment = var.env
    Project     = var.project
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Public website hosting (website endpoint)
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Public access block – website public
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy public read
data "aws_iam_policy_document" "frontend_public_read" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_public_read" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_public_read.json
}

# Use a template index.html 
locals {
  api_url = aws_apigatewayv2_api.http_api.api_endpoint
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  content_type = "text/html"

# templatefile
# index.html ${api_url}
  content = templatefile("${path.root}/index.html", {
    api_url = local.api_url
  })
}

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend.id}"
    
    s3_origin_config {
      origin_access_identity = ""  # Create OAI later
    }
  }

  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "api_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "frontend_website_url" {
  value = aws_s3_bucket_website_configuration.frontend_website.website_endpoint
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
