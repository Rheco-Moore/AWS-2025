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
