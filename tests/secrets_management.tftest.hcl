# Test all API key configuration paths
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

# Path 1: dd_api_key only (auto-create secret)
# This is the default path when no external secret reference is provided.
run "auto_create_secret_test" {
  command = plan

  variables {
    dd_api_key            = "test-api-key-value"
    dd_api_key_secret_arn = null
  }

  # Secret resources should be created
  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 1
    error_message = "Secrets Manager secret should be created when only dd_api_key is provided"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.dd_api_key_secret_version) == 1
    error_message = "Secrets Manager secret version should be created when only dd_api_key is provided"
  }

  # Lambda should use DD_API_KEY_SECRET_ARN (not SSM)
  assert {
    condition     = contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_API_KEY_SECRET_ARN")
    error_message = "DD_API_KEY_SECRET_ARN env var should be present when auto-creating secret"
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_API_KEY_SSM_NAME")
    error_message = "DD_API_KEY_SSM_NAME should not be present when using Secrets Manager"
  }

  # Secret version should also be created alongside the secret
  assert {
    condition     = aws_secretsmanager_secret.dd_api_key_secret[0].name_prefix == "DatadogAPIKey-DatadogForwarder"
    error_message = "Secret name prefix should include the function name"
  }
}

# Path 2: dd_api_key_secret_arn provided (external secret)
# The module should NOT create its own secret and should use the provided ARN.
run "external_secret_arn_test" {
  command = plan

  variables {
    dd_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:DatadogAPIKey-mock"
  }

  # No secret resources should be created
  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "Secrets Manager secret should not be created when dd_api_key_secret_arn is provided"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.dd_api_key_secret_version) == 0
    error_message = "Secrets Manager secret version should not be created when dd_api_key_secret_arn is provided"
  }

  # Lambda should use the provided ARN
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_API_KEY_SECRET_ARN == "arn:aws:secretsmanager:us-east-1:123456789012:secret:DatadogAPIKey-mock"
    error_message = "DD_API_KEY_SECRET_ARN should reference the provided secret ARN"
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_API_KEY_SSM_NAME")
    error_message = "DD_API_KEY_SSM_NAME should not be present when using Secrets Manager"
  }

  # Output should be null (module didn't create the secret)
  assert {
    condition     = output.dd_api_key_secret_arn == null
    error_message = "dd_api_key_secret_arn output should be null when module does not create the secret"
  }
}

# Path 3: dd_api_key_ssm_parameter_name provided (SSM parameter)
# The module should use SSM instead of Secrets Manager entirely.
run "ssm_parameter_test" {
  command = plan

  variables {
    dd_api_key                    = null
    dd_api_key_secret_arn         = null
    dd_api_key_ssm_parameter_name = "/datadog/api-key"
  }

  # No secret resources should be created
  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "Secrets Manager secret should not be created when using SSM parameter"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.dd_api_key_secret_version) == 0
    error_message = "Secrets Manager secret version should not be created when using SSM parameter"
  }

  # Lambda should use DD_API_KEY_SSM_NAME (not secret ARN)
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_API_KEY_SSM_NAME == "/datadog/api-key"
    error_message = "DD_API_KEY_SSM_NAME should be set to the provided SSM parameter name"
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_API_KEY_SECRET_ARN")
    error_message = "DD_API_KEY_SECRET_ARN should not be present when using SSM parameter"
  }

  # Output should be null (no secret created)
  assert {
    condition     = output.dd_api_key_secret_arn == null
    error_message = "dd_api_key_secret_arn output should be null when using SSM parameter"
  }
}

# Path 4: create_dd_api_key_secret = false with external secret ARN
# Explicit opt-out of secret creation (e.g., when secret is created in the same Terraform plan).
run "explicit_no_create_secret_test" {
  command = plan

  variables {
    dd_api_key               = null
    dd_api_key_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ExternalSecret-abc123"
    create_dd_api_key_secret = false
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "Secrets Manager secret should not be created when create_dd_api_key_secret is false"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_API_KEY_SECRET_ARN == "arn:aws:secretsmanager:us-east-1:123456789012:secret:ExternalSecret-abc123"
    error_message = "DD_API_KEY_SECRET_ARN should reference the externally provided secret ARN"
  }
}
