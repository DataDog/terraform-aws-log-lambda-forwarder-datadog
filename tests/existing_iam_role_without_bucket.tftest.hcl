# Test using existing IAM role without providing an existing bucket
# This validates the fix for issue #18: users should be able to use their own IAM role
# while still letting the module create the S3 bucket

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

# Test: existing IAM role with SSM parameter (no bucket specified) - should work
run "existing_role_with_ssm_no_bucket" {
  command = plan

  variables {
    dd_api_key                    = "test-api-key-value"
    dd_site                       = "datadoghq.com"
    existing_iam_role_arn         = "arn:aws:iam::123456789012:role/existing-datadog-role"
    dd_api_key_ssm_parameter_name = "/datadog/api-key"
  }

  # Verify IAM module is not created
  assert {
    condition     = length(module.iam) == 0
    error_message = "IAM module should not be created when existing_iam_role_arn is provided"
  }

  # Verify Lambda uses the existing IAM role
  assert {
    condition     = aws_lambda_function.forwarder.role == "arn:aws:iam::123456789012:role/existing-datadog-role"
    error_message = "Lambda function should use the provided existing IAM role"
  }
}

# Test: existing IAM role with Secrets Manager ARN (no bucket specified) - should work
run "existing_role_with_secret_arn_no_bucket" {
  command = plan

  variables {
    dd_api_key            = "test-api-key-value"
    dd_site               = "datadoghq.com"
    existing_iam_role_arn = "arn:aws:iam::123456789012:role/existing-datadog-role"
    dd_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-AbCdEf"
  }

  # Verify IAM module is not created
  assert {
    condition     = length(module.iam) == 0
    error_message = "IAM module should not be created when existing_iam_role_arn is provided"
  }

  # Verify Lambda uses the existing IAM role
  assert {
    condition     = aws_lambda_function.forwarder.role == "arn:aws:iam::123456789012:role/existing-datadog-role"
    error_message = "Lambda function should use the provided existing IAM role"
  }
}

# Test: existing IAM role with tag fetching enabled (bucket should be created)
run "existing_role_with_tag_fetching" {
  command = plan

  variables {
    dd_api_key                    = "test-api-key-value"
    dd_site                       = "datadoghq.com"
    existing_iam_role_arn         = "arn:aws:iam::123456789012:role/existing-datadog-role"
    dd_api_key_ssm_parameter_name = "/datadog/api-key"
    dd_fetch_lambda_tags          = true
  }

  # Verify IAM module is not created
  assert {
    condition     = length(module.iam) == 0
    error_message = "IAM module should not be created when existing_iam_role_arn is provided"
  }

  # Verify S3 bucket IS created when tag fetching is enabled
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 1
    error_message = "S3 bucket should be created when dd_fetch_lambda_tags is enabled and no existing bucket is provided"
  }
}

# Test: existing IAM role with failed events storage enabled (bucket should be created)
run "existing_role_with_failed_events" {
  command = plan

  variables {
    dd_api_key                    = "test-api-key-value"
    dd_site                       = "datadoghq.com"
    existing_iam_role_arn         = "arn:aws:iam::123456789012:role/existing-datadog-role"
    dd_api_key_ssm_parameter_name = "/datadog/api-key"
    dd_store_failed_events        = true
  }

  # Verify S3 bucket IS created when failed events storage is enabled
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 1
    error_message = "S3 bucket should be created when dd_store_failed_events is enabled and no existing bucket is provided"
  }
}

# Test: existing IAM role WITHOUT API key configuration - should fail validation
run "existing_role_without_api_key_fails" {
  command = plan

  variables {
    dd_api_key            = "test-api-key-value"
    dd_site               = "datadoghq.com"
    existing_iam_role_arn = "arn:aws:iam::123456789012:role/existing-datadog-role"
    # No dd_api_key_ssm_parameter_name or dd_api_key_secret_arn provided
  }

  expect_failures = [
    var.existing_iam_role_arn,
  ]
}
