# Test explicit layer version configuration
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
  dd_api_key     = "test-api-key-value"
  dd_site        = "datadoghq.com"
  layer_version  = "92"
}

run "explicit_layer_version" {
  command = plan

  assert {
    condition     = can(regex(":92$", aws_lambda_function.forwarder.layers[0]))
    error_message = "Lambda layer ARN should end with :92"
  }
}

run "custom_layer_arn" {
  command = plan

  variables {
    layer_version = null
    layer_arn     = "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Forwarder:94"
  }

  assert {
    condition     = aws_lambda_function.forwarder.runtime == "python3.14"
    error_message = "Lambda runtime should be python3.14 for layer version 94"
  }
}

run "user_tags_are_preserved" {
  command = plan

  variables {
    tags = {
      Environment = "test"
      Team        = "platform"
    }
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["Environment"] == "test"
    error_message = "User-provided Environment tag should be preserved"
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["Team"] == "platform"
    error_message = "User-provided Team tag should be preserved"
  }
}
