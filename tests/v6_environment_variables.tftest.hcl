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

run "v5_sets_python_forwarder_env_vars" {
  command = plan

  assert {
    condition     = aws_lambda_function.forwarder.environment[0].variables["DD_TRACE_ENABLED"] == "true"
    error_message = "v5 must set DD_TRACE_ENABLED"
  }
}

run "v6_drops_v5_only_env_vars" {
  command = plan

  variables {
    use_v6 = true
  }

  assert {
    condition = alltrue([
      for k in ["DD_TRACE_ENABLED", "DD_ENHANCED_METRICS", "DD_USE_VPC", "DD_FETCH_LAMBDA_TAGS", "DD_FETCH_LOG_GROUP_TAGS", "DD_FETCH_S3_TAGS", "DD_ENRICH_S3_TAGS", "DD_ENRICH_CLOUDWATCH_TAGS", "DD_TAGS_CACHE_TTL_SECONDS", "DD_STORE_FAILED_EVENTS", "DD_TRACE_INTAKE_URL", "DD_MAX_WORKERS", "DD_USE_COMPRESSION", "DD_FORWARD_LOG"] :
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

run "v6_unsupported_env_vars_trip_the_check" {
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
}
