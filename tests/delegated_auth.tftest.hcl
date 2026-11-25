# Tests for dd_org_uuid (Workload Identity Federation / delegated auth).
#
# All tests here use mock_provider + override_data so they run without real AWS credentials.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDATEST"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
}

variables {
  dd_site = "datadoghq.com"
  region  = "us-east-1"
}

run "org_uuid_alone_skips_secret" {
  command = plan

  variables {
    dd_org_uuid = "12345678-1234-1234-1234-123456789abc"
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "No secret should be created when only dd_org_uuid is set"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_ORG_UUID == "12345678-1234-1234-1234-123456789abc"
    error_message = "DD_ORG_UUID should be set on the Lambda function"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_API_KEY_SECRET_ARN == null
    error_message = "DD_API_KEY_SECRET_ARN should be null when only dd_org_uuid is configured"
  }
}

run "refresh_interval_set" {
  command = plan

  variables {
    dd_org_uuid                             = "12345678-1234-1234-1234-123456789abc"
    dd_delegated_auth_refresh_interval_mins = 30
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_DELEGATED_AUTH_REFRESH_INTERVAL_MINS == "30"
    error_message = "DD_DELEGATED_AUTH_REFRESH_INTERVAL_MINS should be set as a string"
  }
}

run "org_uuid_with_api_key_fallback" {
  command = plan

  variables {
    dd_org_uuid = "12345678-1234-1234-1234-123456789abc"
    dd_api_key  = "test-api-key-value"
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 1
    error_message = "Secret should still be created for the fallback dd_api_key"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_ORG_UUID == "12345678-1234-1234-1234-123456789abc"
    error_message = "DD_ORG_UUID should be set alongside the fallback API key"
  }

  assert {
    condition     = contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_API_KEY_SECRET_ARN")
    error_message = "DD_API_KEY_SECRET_ARN should also be set for the fallback"
  }
}

run "org_uuid_with_existing_iam_role" {
  command = plan

  variables {
    dd_org_uuid           = "12345678-1234-1234-1234-123456789abc"
    existing_iam_role_arn = "arn:aws:iam::123456789012:role/MyExistingRole"
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(module.iam) == 0
    error_message = "IAM module should not be instantiated when existing_iam_role_arn is set"
  }

  assert {
    condition     = aws_lambda_function.forwarder.role == "arn:aws:iam::123456789012:role/MyExistingRole"
    error_message = "Lambda should use the existing IAM role"
  }
}
