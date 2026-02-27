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
# This example reproduces the scenario from issue #8:
#
#   "Invalid count argument" when dd_api_key_secret_arn is set to a reference
#   from a resource created in the SAME Terraform plan.
#
# Before the fix, this would fail at `terraform plan` with:
#   Error: Invalid count argument
#   The "count" value depends on resource attributes that cannot be determined
#   until apply, so Terraform cannot predict how many instances will be created.
#
# The fix: set create_dd_api_key_secret = false so the module knows at plan
# time not to create its own secret, bypassing the unknown-value problem.
# ─────────────────────────────────────────────────────────────────────────────

# Secret created in the SAME Terraform plan as the forwarder module.
# Its ARN is unknown at plan time — this is exactly what triggered the bug.
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

  # Pass the ARN from the resource above — this value is UNKNOWN at plan time.
  # Without create_dd_api_key_secret = false this caused "Invalid count argument".
  dd_api_key_secret_arn    = aws_secretsmanager_secret.dd_api_key.arn
  create_dd_api_key_secret = false

  function_name = var.function_name
  region        = var.aws_region

  tags = {
    example   = "external-secret"
    terraform = "true"
  }
}
