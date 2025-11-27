variable "instance_name" {
  description = "Value of the EC2 instance's Name tag."
  type        = string
  default     = "aws-rm-terraform"
}

variable "instance_type" {
  description = "The EC2 instance's type for PROD."
  type        = string
  default     = "m7i-flex.large"
}

# Project and environment
variable "project" {
  description = "Project name for resource naming"
  type        = string
  default     = "myapp"
}

variable "env" {
  description = "Environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Lambda function variables
variable "lambda_zip_path" {
  description = "Path to the Lambda function zip file"
  type        = string
  default     = "lambda_function.zip"
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.12"
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "app.handler"
}

variable "environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
}

# Network variables
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

# Frontend variables
variable "frontend_bucket_name" {
  description = "Name for the frontend S3 bucket (will have random suffix appended)"
  type        = string
  default     = "my-web-frontend"
}