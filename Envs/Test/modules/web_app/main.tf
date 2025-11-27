variable "project" {
  description = "Project name prefix for the Lambda function"
  type        = string
}

variable "env" {
  description = "Environment name (e.g. dev, test, prod)"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda zip file"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime (e.g. nodejs18.x)"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_handler" {
  description = "Lambda handler (e.g. index.handler)"
  type        = string
  default     = "index.handler"
}

variable "environment_variables" {
  description = "Environment variables for the Lambda"
  type        = map(string)
  default     = {}
}

variable "lambda_role_arn" {
  description = "IAM role ARN for the Lambda execution role"
  type        = string
}

// ==========
// Lambda function
// ==========

resource "aws_lambda_function" "web_app" {
  function_name = "${var.project}-${var.env}-web-app"
  role          = var.lambda_role_arn

  runtime = var.lambda_runtime
  handler = var.lambda_handler

  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  environment {
    variables = var.environment_variables
  }
}

// ==========
// Outputs
// ==========

output "lambda_invoke_arn" {
  description = "Invoke ARN for the Lambda function"
  value       = aws_lambda_function.web_app.invoke_arn
}

output "lambda_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.web_app.function_name
}
