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
  alias  = "us_east_1"
  region = "us-east-1"
}
provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"
}

module "datadog_forwarder_us_east_1" {
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
  providers = {
    aws = aws.us_east_1
  }
}
module "datadog_forwarder_us_east_2" {
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
  providers = {
    aws = aws.us_east_2
  }
}
