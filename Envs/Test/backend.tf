terraform {
  # for local backend, this can be empty.
  # for S3 backend, configure it here.
}

terraform {
  backend "s3" {
    bucket         = "rhecomoore-terraform-state-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}