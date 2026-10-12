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
      region = "us-east-1"
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
  dd_site               = "datadoghq.com"
  region                = "us-east-1"
  dd_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-dd-key-AbCdEf"
}

override_data {
  target = data.http.forwarder_versions[0]
  values = {
    response_body = "{\"latest\":{\"layer_version\":\"97\",\"forwarder_version\":\"5.3.0\"},\"mappings\":{\"92\":\"5.1.0\"}}"
  }
}

override_data {
  target = data.http.forwarder_zip_versions[0]
  values = {
    response_body = "{\"latest\":{\"forwarder_version\":\"6.0.0-rc.1\",\"release_date\":\"2026-09-15\"}}"
  }
}

run "v6_tag_fetch_flags_create_no_bucket" {
  command = plan

  variables {
    use_v6                  = true
    dd_fetch_lambda_tags    = true
    dd_fetch_log_group_tags = true
    dd_fetch_s3_tags        = true
  }

  expect_failures = [
    check.v6_unsupported_environment_variables_have_no_effect,
  ]

  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 0
    error_message = "v6 must not create a bucket for tag caching"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_S3_BUCKET_NAME"] == null
    error_message = "v6 must not set DD_S3_BUCKET_NAME when only tag fetching was requested"
  }
}

run "v6_store_failed_events_creates_bucket" {
  command = plan

  variables {
    use_v6                 = true
    dd_store_failed_events = true
  }

  override_resource {
    target          = aws_s3_bucket.forwarder_bucket[0]
    override_during = plan
    values = {
      id = "module-created-bucket"
    }
  }

  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 1
    error_message = "v6 must create a bucket when failed-event storage is requested"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_S3_BUCKET_NAME"] == "module-created-bucket"
    error_message = "v6 must pass the created bucket's name as DD_S3_BUCKET_NAME"
  }
}

run "v6_sqs_supersedes_bucket" {
  command = plan

  variables {
    use_v6                 = true
    dd_store_failed_events = true
    dd_sqs_queue_url       = "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
  }

  assert {
    condition     = length(aws_s3_bucket.forwarder_bucket) == 0
    error_message = "v6 must not create a bucket when an SQS queue is configured"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_S3_BUCKET_NAME"] == null
    error_message = "v6 must not set DD_S3_BUCKET_NAME when the failure sink is SQS"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_SQS_QUEUE_URL"] == "https://sqs.us-east-1.amazonaws.com/123456789012/my-failed-events-queue"
    error_message = "v6 must pass DD_SQS_QUEUE_URL"
  }
}

run "v6_existing_bucket_without_storage" {
  command = plan

  variables {
    use_v6                            = true
    dd_forwarder_existing_bucket_name = "my-existing-bucket"
    dd_store_failed_events            = false
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_S3_BUCKET_NAME"] == null
    error_message = "v6 must not set DD_S3_BUCKET_NAME when failed-event storage was not requested"
  }
}

run "v6_existing_bucket_with_storage" {
  command = plan

  variables {
    use_v6                            = true
    dd_forwarder_existing_bucket_name = "my-existing-bucket"
    dd_store_failed_events            = true
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_S3_BUCKET_NAME"] == "my-existing-bucket"
    error_message = "v6 must set DD_S3_BUCKET_NAME when failed-event storage is requested"
  }
}

run "v5_existing_bucket_always_passed" {
  command = plan

  variables {
    dd_forwarder_existing_bucket_name = "my-existing-bucket"
    dd_store_failed_events            = false
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_S3_BUCKET_NAME"] == "my-existing-bucket"
    error_message = "v5 must pass DD_S3_BUCKET_NAME whenever a bucket exists"
  }
}
