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

run "v5_default_unchanged" {
  command = plan

  assert {
    condition     = aws_lambda_function.forwarder.handler == "lambda_function.lambda_handler"
    error_message = "v5 handler must be lambda_function.lambda_handler"
  }

  assert {
    condition     = startswith(aws_lambda_function.forwarder.runtime, "python")
    error_message = "v5 runtime must be a python runtime"
  }

  assert {
    condition     = anytrue([for l in aws_lambda_function.forwarder.layers : strcontains(l, "layer:Datadog-Forwarder:")])
    error_message = "v5 must attach the Datadog-Forwarder layer"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_TRACE_ENABLED"] == "true"
    error_message = "v5 must set DD_TRACE_ENABLED"
  }

  assert {
    condition     = length(data.http.forwarder_zip_versions) == 0
    error_message = "v5 must not fetch the zip version manifest"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == null && aws_lambda_function.forwarder.s3_key == null
    error_message = "v5 must load code from the layer placeholder, not from S3"
  }
}

run "v6" {
  command = plan

  variables {
    use_v6 = true
  }

  assert {
    condition     = aws_lambda_function.forwarder.runtime == "provided.al2023"
    error_message = "v6 runtime must be provided.al2023"
  }

  assert {
    condition     = aws_lambda_function.forwarder.handler == "bootstrap"
    error_message = "v6 handler must be bootstrap"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == "datadog-log-forwarder-us-east-1"
    error_message = "v6 bucket must default to datadog-log-forwarder-{region}"
  }

  # zip_version defaults to "latest", which must resolve through the manifest
  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1.zip"
    error_message = "v6 key must be derived from the resolved zip_version, not the literal \"latest\""
  }

  assert {
    condition     = aws_lambda_function.forwarder.filename == null
    error_message = "v6 must not set filename (code comes from S3, not the placeholder zip)"
  }

  assert {
    condition     = length(aws_lambda_function.forwarder.layers) == 0
    error_message = "v6 must not attach the Datadog-Forwarder layer (only user-supplied additional_layers)"
  }

  assert {
    condition     = length(data.http.forwarder_versions) == 0
    error_message = "v6 must not fetch the layer version manifest"
  }

  assert {
    condition     = length(data.http.forwarder_zip_versions) == 1
    error_message = "zip_version = \"latest\" must fetch the zip manifest to resolve it"
  }

  assert {
    condition = alltrue([
      for k in ["DD_TRACE_ENABLED", "DD_ENHANCED_METRICS", "DD_USE_VPC", "DD_FETCH_LAMBDA_TAGS", "DD_FETCH_LOG_GROUP_TAGS", "DD_FETCH_S3_TAGS", "DD_ENRICH_S3_TAGS", "DD_ENRICH_CLOUDWATCH_TAGS", "DD_TAGS_CACHE_TTL_SECONDS", "DD_STORE_FAILED_EVENTS", "DD_URL", "DD_API_URL", "DD_TRACE_INTAKE_URL", "DD_MAX_WORKERS", "DD_USE_COMPRESSION", "DD_FORWARD_LOG"] :
      !contains(keys(aws_lambda_function.forwarder.environment[0].variables), k)
    ])
    error_message = "v6 must not set v5-only environment variables"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_SITE"] == "datadoghq.com"
    error_message = "v6 must set DD_SITE"
  }

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_API_KEY_SECRET_ARN"] == "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-dd-key-AbCdEf"
    error_message = "v6 must still receive the API key secret ARN"
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["dd_forwarder_version"] == "6.0.0-rc.1"
    error_message = "v6 must tag the function with dd_forwarder_version"
  }
}

# Lambda requires the code bucket to live in the function's region.
run "zip_bucket_follows_region" {
  command = plan

  variables {
    use_v6 = true
    region = "eu-west-1"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == "datadog-log-forwarder-eu-west-1"
    error_message = "v6 bucket must follow local.region, not the provider region"
  }
}

run "zip_bucket_override" {
  command = plan

  variables {
    use_v6     = true
    zip_bucket = "my-forwarder-mirror"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == "my-forwarder-mirror"
    error_message = "zip_bucket must override the derived bucket name"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1.zip"
    error_message = "overriding the bucket must not change the derived key"
  }
}

run "zip_version_pinned_skips_manifest" {
  command = plan

  variables {
    use_v6      = true
    zip_version = "6.0.1"
  }

  assert {
    condition     = length(data.http.forwarder_zip_versions) == 0
    error_message = "a pinned zip_version must not fetch the zip manifest"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.1.zip"
    error_message = "a pinned zip_version must be used verbatim in the key"
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["dd_forwarder_version"] == "6.0.1"
    error_message = "a pinned zip_version must be used as dd_forwarder_version"
  }
}

run "zip_version_pinned_unknown_to_manifest" {
  command = plan

  variables {
    use_v6      = true
    zip_version = "9.9.9"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-9.9.9.zip"
    error_message = "any pinned zip_version must drive the key without a manifest lookup"
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["dd_forwarder_version"] == "9.9.9"
    error_message = "a pinned zip_version must be tagged even when absent from the manifest"
  }
}

run "v6_keeps_proxy_env_vars" {
  command = plan

  variables {
    use_v6            = true
    dd_http_proxy_url = "http://proxy.internal:3128"
    dd_no_proxy       = "169.254.169.254"
  }

  assert {
    condition = alltrue([
      aws_lambda_function.forwarder.environment[0].variables["HTTP_PROXY"] == "http://proxy.internal:3128",
      aws_lambda_function.forwarder.environment[0].variables["HTTPS_PROXY"] == "http://proxy.internal:3128",
      aws_lambda_function.forwarder.environment[0].variables["NO_PROXY"] == "169.254.169.254",
    ])
    error_message = "v6 must keep the proxy environment variables"
  }
}

run "v6_keeps_vpc_config" {
  command = plan

  variables {
    use_v6                 = true
    dd_use_vpc             = true
    vpc_security_group_ids = ["sg-12345678"]
    vpc_subnet_ids         = ["subnet-12345678"]
  }

  assert {
    condition     = length(aws_lambda_function.forwarder.vpc_config) == 1
    error_message = "v6 must still configure vpc_config when dd_use_vpc is true"
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.forwarder.environment[0].variables), "DD_USE_VPC")
    error_message = "v6 must not set DD_USE_VPC (the Go forwarder ignores it)"
  }
}

run "v6_ignores_tag_fetch_flags" {
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

  # DD_S3_BUCKET_NAME is always a key in env_common, so "not set" means a null
  # value, not an absent key.
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

run "v6_keeps_additional_layers" {
  command = plan

  variables {
    use_v6            = true
    additional_layers = ["arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Extension-ARM:83"]
  }

  assert {
    condition = length(aws_lambda_function.forwarder.layers) == 1 && contains(
      aws_lambda_function.forwarder.layers,
      "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Extension-ARM:83"
    )
    error_message = "v6 must attach additional_layers and nothing else"
  }
}
