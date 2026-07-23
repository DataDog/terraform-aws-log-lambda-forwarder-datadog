# Test the default configuration of the Datadog Forwarder module
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

  mock_data "aws_lambda_layer_version" {
    defaults = {
      compatible_runtimes = [
        "python3.14",
      ]
    }
  }
}

variables {
  dd_api_key = "test-api-key-value"
  dd_site    = "datadoghq.com"
}

run "default_config_test" {
  command = plan

  # === Lambda Function Configuration ===
  assert {
    condition     = aws_lambda_function.forwarder.function_name == "DatadogForwarder"
    error_message = "Lambda function should have default name 'DatadogForwarder'"
  }

  assert {
    condition     = aws_lambda_function.forwarder.runtime == "python3.14"
    error_message = "Lambda function should use Python 3.14 runtime"
  }

  assert {
    condition     = length(aws_lambda_function.forwarder.architectures) == 1
    error_message = "Lambda function should have one architecture specified"
  }

  assert {
    condition     = aws_lambda_function.forwarder.architectures[0] == "arm64"
    error_message = "Lambda function should use ARM64 architecture"
  }

  assert {
    condition     = aws_lambda_function.forwarder.memory_size == 1024
    error_message = "Lambda function should have default memory size of 1024MB"
  }

  assert {
    condition     = aws_lambda_function.forwarder.timeout == 120
    error_message = "Lambda function should have default timeout of 120 seconds"
  }

  assert {
    condition     = length(aws_lambda_function.forwarder.layers) > 0
    error_message = "Lambda function should use layers by default (install_as_layer = true)"
  }

  # === Environment Configuration ===
  assert {
    condition     = length(aws_lambda_function.forwarder.environment) == 1
    error_message = "Lambda function should have environment configuration"
  }

  assert {
    condition     = length(aws_lambda_function.forwarder.vpc_config) == 0
    error_message = "VPC configuration should not be set by default"
  }

  # === IAM Configuration ===
  assert {
    condition     = length(module.iam) == 1
    error_message = "IAM module should be used when no existing_iam_role_arn is provided"
  }

  # === Secrets Management ===
  # Default path: dd_api_key provided, no external secret reference → module creates secret
  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 1
    error_message = "Secrets Manager secret should be created by default when only dd_api_key is provided"
  }

  # === Storage Configuration ===
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 0
    error_message = "S3 bucket should not be created with default configuration (no tag fetching enabled)"
  }

  # === CloudWatch Configuration ===
  assert {
    condition     = aws_cloudwatch_log_group.forwarder_log_group.retention_in_days == 90
    error_message = "CloudWatch Log Group should have default retention of 90 days"
  }

  # === Lambda Permissions ===
  assert {
    condition     = aws_lambda_permission.cloudwatch_logs_invoke.principal == "logs.amazonaws.com"
    error_message = "CloudWatch Logs permission should be created"
  }

  assert {
    condition     = aws_lambda_permission.s3_invoke.principal == "s3.amazonaws.com"
    error_message = "S3 permission should be created"
  }

  assert {
    condition     = aws_lambda_permission.sns_invoke.principal == "sns.amazonaws.com"
    error_message = "SNS permission should be created"
  }

  assert {
    condition     = aws_lambda_permission.eventbridge_invoke.principal == "events.amazonaws.com"
    error_message = "EventBridge permission should be created"
  }

  # === Output Validation ===
  assert {
    condition     = output.datadog_forwarder_function_name == "DatadogForwarder"
    error_message = "datadog_forwarder_function_name should match expected value"
  }
}

# Test environment variable values
run "environment_variables_test" {
  command = plan

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_SITE == "datadoghq.com"
    error_message = "DD_SITE environment variable should be set correctly"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_TAGS_CACHE_TTL_SECONDS == "300"
    error_message = "DD_TAGS_CACHE_TTL_SECONDS should have default value of 300"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_USE_VPC == "false"
    error_message = "DD_USE_VPC should be false by default"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_TRACE_ENABLED == "true"
    error_message = "DD_TRACE_ENABLED should be true by default"
  }

  # Test that optional environment variables are null when not provided
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_TAGS == null
    error_message = "DD_TAGS should be null when not provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FETCH_LAMBDA_TAGS == null
    error_message = "DD_FETCH_LAMBDA_TAGS should be null when not provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FETCH_S3_TAGS == null
    error_message = "DD_FETCH_S3_TAGS should be null when not provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FORWARD_LOG == null
    error_message = "DD_FORWARD_LOG should be null when not provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_LOG_LEVEL == null
    error_message = "DD_LOG_LEVEL should be null when not provided"
  }

  # Verify secret ARN path is used (not SSM)
  assert {
    condition     = contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_API_KEY_SECRET_ARN")
    error_message = "DD_API_KEY_SECRET_ARN should be present when module auto-creates the secret"
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_API_KEY_SSM_NAME")
    error_message = "DD_API_KEY_SSM_NAME should not be present when using Secrets Manager"
  }
}
