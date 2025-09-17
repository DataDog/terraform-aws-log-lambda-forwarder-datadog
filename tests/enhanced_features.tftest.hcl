# Test enhanced features configuration
provider "aws" {
  region = "us-east-1"
}

variables {
  dd_api_key                   = "test-api-key-value"
  dd_site                      = "datadoghq.com"
  dd_fetch_lambda_tags         = true
  dd_fetch_log_group_tags      = true
  dd_fetch_step_functions_tags = true
  dd_fetch_s3_tags             = true
  dd_store_failed_events       = true
  dd_forward_log               = false
  dd_trace_enabled             = false
  memory_size                  = 2048
  timeout                      = 300
  layer_version                = "80"
}

run "enhanced_features_test" {
  command = plan

  # Test Lambda configuration with enhanced settings
  assert {
    condition     = aws_lambda_function.forwarder.memory_size == 2048
    error_message = "Lambda function should have configured memory size of 2048MB"
  }

  assert {
    condition     = aws_lambda_function.forwarder.timeout == 300
    error_message = "Lambda function should have configured timeout of 300 seconds"
  }

  # Test that S3 bucket is created when features require it
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 1
    error_message = "S3 bucket should be created when tag fetching or failed events storage is enabled"
  }
}
run "enhanced_features_env_vars_test" {
  command = apply

  assert {
    condition     = aws_lambda_function.forwarder.layers[0] == "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Forwarder:80"
    error_message = "Lambda function should use layer version 80"
  }

  # Test tag fetching environment variables
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FETCH_LAMBDA_TAGS == "true"
    error_message = "DD_FETCH_LAMBDA_TAGS should be true when enabled"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FETCH_LOG_GROUP_TAGS == "true"
    error_message = "DD_FETCH_LOG_GROUP_TAGS should be true when enabled"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FETCH_STEP_FUNCTIONS_TAGS == "true"
    error_message = "DD_FETCH_STEP_FUNCTIONS_TAGS should be true when enabled"
  }

  # Test trace and log forwarding configuration
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_TRACE_ENABLED == "false"
    error_message = "DD_TRACE_ENABLED should be false when disabled"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_FORWARD_LOG == "false"
    error_message = "DD_FORWARD_LOG should be false when disabled"
  }

  # Test failed events storage
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_STORE_FAILED_EVENTS == "true"
    error_message = "DD_STORE_FAILED_EVENTS should be true when enabled"
  }

  # Test S3 bucket name is set
  assert {
    condition     = length(aws_lambda_function.forwarder.environment[0].variables.DD_S3_BUCKET_NAME) > 0
    error_message = "DD_S3_BUCKET_NAME should be set when S3 bucket is created"
  }
}
