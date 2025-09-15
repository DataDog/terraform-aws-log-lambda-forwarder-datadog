terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "datadog_forwarder" {
  source = "../../"

  # Required - API key will be stored in Secrets Manager
  # Alternatively, use dd_api_key_secret_arn to reference an existing Secrets Manager secret
  # Or use dd_api_key_ssm_parameter_name to reference an existing SSM Parameter
  dd_api_key = var.datadog_api_key
  dd_site    = var.datadog_site

  # Basic Lambda configuration
  function_name = var.function_name

  # Optional: Custom tags for all AWS resources created by the module
  tags = {
    environment       = "production"
    terraform         = "true"
    dd_forwarder_name = var.function_name
  }
}

### OPTIONAL - Example CloudWatch Log Group to demonstrate forwarding logs
resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/test-log-group-basic"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_stream" "example" {
  name           = "test"
  log_group_name = aws_cloudwatch_log_group.example.name
}

# Log subscription filter to forward logs to Datadog
resource "aws_cloudwatch_log_subscription_filter" "datadog_log_filter" {
  name            = "datadog-log-filter"
  log_group_name  = aws_cloudwatch_log_group.example.name
  filter_pattern  = ""
  destination_arn = module.datadog_forwarder.datadog_forwarder_arn
}
