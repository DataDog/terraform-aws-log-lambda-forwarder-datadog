# Test using existing IAM role and S3 bucket
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

variables {
  dd_api_key                        = "test-api-key-value"
  dd_site                           = "datadoghq.com"
  existing_iam_role_arn             = "arn:aws:iam::123456789012:role/existing-datadog-role"
  dd_forwarder_existing_bucket_name = "existing-datadog-bucket"
  dd_api_key_secret_arn             = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-AbCdEf"
}

run "existing_resources_test" {
  command = plan

  # Test that IAM module is not created when using existing role
  assert {
    condition     = length(module.iam) == 0
    error_message = "IAM module should not be created when existing_iam_role_arn is provided"
  }

  # Test that S3 bucket is not created when using existing bucket
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 0
    error_message = "S3 bucket should not be created when dd_forwarder_existing_bucket_name is provided"
  }

  # Test that Secrets Manager secret is not created when using existing secret
  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "Secrets Manager secret should not be created when dd_api_key_secret_arn is provided"
  }

  # Test that Lambda uses the existing IAM role
  assert {
    condition     = aws_lambda_function.forwarder.role == "arn:aws:iam::123456789012:role/existing-datadog-role"
    error_message = "Lambda function should use the provided existing IAM role"
  }

  # Test that environment variables reference existing resources
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_S3_BUCKET_NAME == "existing-datadog-bucket"
    error_message = "DD_S3_BUCKET_NAME should reference the existing bucket"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_API_KEY_SECRET_ARN == "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-AbCdEf"
    error_message = "DD_API_KEY_SECRET_ARN should reference the existing secret"
  }
}
