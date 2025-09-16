# Test optional environment variables are set when provided
provider "aws" {
  region = "us-east-1"
}

variables {
  dd_api_key                    = "test-api-key-value"
  dd_site                       = "datadoghq.com"
  dd_tags                       = "env:test,service:forwarder"
  dd_fetch_lambda_tags          = true
  dd_fetch_log_group_tags       = true
  dd_forward_log                = false
  dd_log_level                  = "DEBUG"
  dd_compression_level          = "9"
  dd_max_workers                = "10"
  redact_ip                     = "true"
  redact_email                  = "true"
  additional_target_lambda_arns = "arn:aws:lambda:us-east-1:123456789012:function:test1,arn:aws:lambda:us-east-1:123456789012:function:test2"
}

run "optional_env_vars_test" {
  command = apply

  # Test that optional environment variables ARE set when provided
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_TAGS == "env:test,service:forwarder"
    error_message = "DD_TAGS should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FETCH_LAMBDA_TAGS == "true"
    error_message = "DD_FETCH_LAMBDA_TAGS should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FETCH_LOG_GROUP_TAGS == "true"
    error_message = "DD_FETCH_LOG_GROUP_TAGS should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FORWARD_LOG == "false"
    error_message = "DD_FORWARD_LOG should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_LOG_LEVEL == "DEBUG"
    error_message = "DD_LOG_LEVEL should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_COMPRESSION_LEVEL == "9"
    error_message = "DD_COMPRESSION_LEVEL should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_MAX_WORKERS == "10"
    error_message = "DD_MAX_WORKERS should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.REDACT_IP == "true"
    error_message = "REDACT_IP should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.REDACT_EMAIL == "true"
    error_message = "REDACT_EMAIL should be set when provided"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_ADDITIONAL_TARGET_LAMBDAS == "arn:aws:lambda:us-east-1:123456789012:function:test1,arn:aws:lambda:us-east-1:123456789012:function:test2"
    error_message = "DD_ADDITIONAL_TARGET_LAMBDAS should be set when provided"
  }

  # Test that S3 bucket is created when tag fetching is enabled
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 1
    error_message = "S3 bucket should be created when tag fetching is enabled"
  }
}