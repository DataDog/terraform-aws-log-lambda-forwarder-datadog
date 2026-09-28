# Validates the external-secret pattern: a secret created in the same plan whose ARN
# (unknown at plan time) is passed to the forwarder module via create_dd_api_key_secret=false.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
}

variables {
  datadog_api_key = "test-api-key"
  aws_region      = "us-east-1"
}

run "external_secret_plan_succeeds" {
  command = plan

  override_data {
    target = module.datadog_forwarder.data.aws_s3_object.forwarder_versions
    values = {
      body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  # The forwarder module must not attempt to create its own secret —
  # the caller owns the secret lifecycle. The module output is null when no secret is created.
  assert {
    condition     = module.datadog_forwarder.dd_api_key_secret_arn == null
    error_message = "Forwarder module must not create a secret when create_dd_api_key_secret=false"
  }

  # The externally-created secret must be planned
  assert {
    condition     = aws_secretsmanager_secret.dd_api_key.name_prefix != null
    error_message = "Caller-owned secret should be planned"
  }
}
