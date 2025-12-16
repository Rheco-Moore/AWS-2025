variable "instance_name" {
  description = "Value of the EC2 instance's Name tag."
  type        = string
  default     = "dev-app-server"
}

variable "instance_type" {
  description = "The EC2 instance's type for DEV."
  type        = string
  default     = "t3.micro"
}

variable "env" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name for development"
  type        = string
  default     = "webapp-dev"
}

variable "vpc_cidr" {
  description = "CIDR block for development VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "allow_ssh_from_anywhere" {
  description = "Whether to allow SSH access from anywhere (0.0.0.0/0)"
  type        = bool
  default     = true  # Easier access for developers
}

variable "enable_debug_logging" {
  description = "Enable verbose debug logging for development"
  type        = bool
  default     = true
}

variable "availability_zones" {
  description = "AZs for development environment"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "private_subnets" {
  description = "Private subnets for development"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "public_subnets" {
  description = "Public subnets for development"
  type        = list(string)
  default     = ["10.1.101.0/24"]
}
