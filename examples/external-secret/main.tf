terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────────────────
# This example demonstrates creating a Secrets Manager secret in the same
# Terraform plan and passing its ARN to the forwarder module.
#
# When the secret is created in the same plan, its ARN is unknown at plan time.
# Setting create_dd_api_key_secret = false tells the module not to create its
# own secret, allowing Terraform to resolve the plan without issues.
# ─────────────────────────────────────────────────────────────────────────────

# Secret created in the same Terraform plan as the forwarder module.
resource "aws_secretsmanager_secret" "dd_api_key" {
  name_prefix = "datadog-api-key-"
  description = "Datadog API key managed externally by the caller"
}

resource "aws_secretsmanager_secret_version" "dd_api_key" {
  secret_id     = aws_secretsmanager_secret.dd_api_key.id
  secret_string = var.datadog_api_key
}

module "datadog_forwarder" {
  source = "../../"

  dd_site = var.datadog_site

  # Pass the ARN from the resource above — its value is unknown at plan time.
  # Setting create_dd_api_key_secret = false tells the module to skip secret creation.
  dd_api_key_secret_arn    = aws_secretsmanager_secret.dd_api_key.arn
  create_dd_api_key_secret = false

  function_name = var.function_name
  region        = var.aws_region

  tags = {
    example   = "external-secret"
    terraform = "true"
  }
}
