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
  target = data.http.forwarder_zip_versions[0]
  values = {
    response_body = "{\"latest\":{\"forwarder_version\":\"6.0.0-rc.1\",\"release_date\":\"2026-09-15\"}}"
  }
}

run "v6_disables_async_retries" {
  command = plan

  variables {
    use_v6 = true
  }

  assert {
    condition     = length(aws_lambda_function_event_invoke_config.forwarder_invoke_config) == 1
    error_message = "v6 must manage the event invoke config"
  }

  assert {
    condition     = aws_lambda_function_event_invoke_config.forwarder_invoke_config[0].maximum_retry_attempts == 0
    error_message = "v6 must set maximum_retry_attempts to 0"
  }

  assert {
    condition     = aws_lambda_function_event_invoke_config.forwarder_invoke_config[0].function_name == aws_lambda_function.forwarder.function_name
    error_message = "invoke config must target the forwarder function"
  }
}

run "v6_invoke_config_follows_region" {
  command = plan

  variables {
    use_v6 = true
    region = "eu-west-1"
  }

  assert {
    condition     = aws_lambda_function_event_invoke_config.forwarder_invoke_config[0].region == "eu-west-1"
    error_message = "invoke config must be created in local.region, not the provider default region"
  }
}
