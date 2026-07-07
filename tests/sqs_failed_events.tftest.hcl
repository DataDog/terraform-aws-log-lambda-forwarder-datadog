# Test SQS queue support for failed event storage

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

# Test: SQS URL auto-enables DD_STORE_FAILED_EVENTS and skips S3 bucket creation
run "sqs_auto_enables_store_failed_events" {
  command = plan

  variables {
    dd_api_key       = "test-api-key-value"
    dd_site          = "datadoghq.com"
    dd_sqs_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
  }

  # No S3 bucket should be created when only SQS is configured
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 0
    error_message = "S3 bucket should not be created when dd_sqs_queue_url is set and no tag fetching is enabled"
  }

  # DD_STORE_FAILED_EVENTS should be auto-enabled
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_STORE_FAILED_EVENTS == "true"
    error_message = "DD_STORE_FAILED_EVENTS should be automatically set to true when dd_sqs_queue_url is provided"
  }

  # DD_SQS_QUEUE_URL should be set
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_SQS_QUEUE_URL == "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
    error_message = "DD_SQS_QUEUE_URL should be set to the provided SQS queue URL"
  }

  # IAM policy should include SQS permissions
  assert {
    condition     = length(module.iam) == 1
    error_message = "IAM module should be created"
  }
}

# Test: SQS with tag fetching still creates S3 bucket for caching
run "sqs_with_tag_fetching_creates_s3" {
  command = plan

  variables {
    dd_api_key           = "test-api-key-value"
    dd_site              = "datadoghq.com"
    dd_sqs_queue_url     = "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
    dd_fetch_lambda_tags = true
  }

  # S3 bucket should be created for tag caching
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 1
    error_message = "S3 bucket should be created when dd_fetch_lambda_tags is enabled, even with SQS configured"
  }

  # DD_STORE_FAILED_EVENTS should still be enabled
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_STORE_FAILED_EVENTS == "true"
    error_message = "DD_STORE_FAILED_EVENTS should be true when dd_sqs_queue_url is provided"
  }

  # DD_SQS_QUEUE_URL should be set
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_SQS_QUEUE_URL == "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
    error_message = "DD_SQS_QUEUE_URL should be set"
  }
}

# Test: SQS with existing IAM role - no IAM module, no S3 bucket
run "sqs_with_existing_iam_role" {
  command = plan

  variables {
    dd_site                       = "datadoghq.com"
    dd_sqs_queue_url              = "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
    existing_iam_role_arn         = "arn:aws:iam::123456789012:role/existing-datadog-role"
    dd_api_key_ssm_parameter_name = "/datadog/api-key"
  }

  # No IAM module
  assert {
    condition     = length(module.iam) == 0
    error_message = "IAM module should not be created when existing_iam_role_arn is provided"
  }

  # No S3 bucket
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 0
    error_message = "S3 bucket should not be created when only SQS is configured"
  }

  # DD_STORE_FAILED_EVENTS should be enabled
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_STORE_FAILED_EVENTS == "true"
    error_message = "DD_STORE_FAILED_EVENTS should be true when dd_sqs_queue_url is provided"
  }
}

# Test: SQS with scheduled retry creates scheduler resources
run "sqs_with_scheduled_retry" {
  command = plan

  variables {
    dd_api_key                      = "test-api-key-value"
    dd_site                         = "datadoghq.com"
    dd_sqs_queue_url                = "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
    dd_schedule_retry_failed_events = true
  }

  # Scheduler resources should be created
  assert {
    condition     = length(aws_scheduler_schedule.scheduled_retry) == 1
    error_message = "Scheduler should be created when SQS is configured with dd_schedule_retry_failed_events"
  }

  assert {
    condition     = length(aws_iam_role.scheduled_retry) == 1
    error_message = "Scheduler IAM role should be created when SQS is configured with dd_schedule_retry_failed_events"
  }
}

# Test: Invalid SQS URL validation
run "invalid_sqs_url_fails_validation" {
  command = plan

  variables {
    dd_api_key       = "test-api-key-value"
    dd_site          = "datadoghq.com"
    dd_sqs_queue_url = "not-a-valid-url"
  }

  expect_failures = [
    var.dd_sqs_queue_url,
  ]
}

# Test: S3 fallback unchanged - dd_store_failed_events without SQS still creates S3 bucket
run "s3_fallback_unchanged" {
  command = plan

  variables {
    dd_api_key             = "test-api-key-value"
    dd_site                = "datadoghq.com"
    dd_store_failed_events = true
  }

  # S3 bucket should be created for failed events
  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 1
    error_message = "S3 bucket should be created when dd_store_failed_events is true and no SQS queue is configured"
  }

  # DD_STORE_FAILED_EVENTS should be enabled
  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables.DD_STORE_FAILED_EVENTS == "true"
    error_message = "DD_STORE_FAILED_EVENTS should be true when dd_store_failed_events is enabled"
  }

  # DD_SQS_QUEUE_URL should not be set
  assert {
    condition     = !contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_SQS_QUEUE_URL") || aws_lambda_function.forwarder.environment[0].variables.DD_SQS_QUEUE_URL == null
    error_message = "DD_SQS_QUEUE_URL should not be set when no SQS queue is configured"
  }
}


# Test: IAM SQS permissions are included when dd_sqs_queue_url is set
run "iam_sqs_permissions" {
  command = plan

  variables {
    dd_api_key       = "test-api-key-value"
    dd_site          = "datadoghq.com"
    dd_sqs_queue_url = "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
  }

  # IAM module should be created with SQS permissions
  assert {
    condition     = length(module.iam) == 1
    error_message = "IAM module should be created"
  }
}
