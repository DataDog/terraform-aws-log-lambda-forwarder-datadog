# Test the dd_forwarder_version tag functionality
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

  mock_data "aws_lambda_layer_version" {
    defaults = {
      compatible_runtimes = [
        "python3.12",
        "python3.14",
        "python3.13"
      ]
    }
  }
}

variables {
  dd_api_key = "test-api-key-value"
  dd_site    = "datadoghq.com"
}

# Test with layer_version = "latest" (default)
run "version_tag_with_latest" {
  command = plan

  # Lambda should have dd_forwarder_version tag
  assert {
    condition     = contains(keys(aws_lambda_function.forwarder.tags), "dd_forwarder_version")
    error_message = "Lambda function should have dd_forwarder_version tag"
  }

  # Tag should be a semantic version (e.g., "5.1.0")
  assert {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", aws_lambda_function.forwarder.tags["dd_forwarder_version"]))
    error_message = "dd_forwarder_version tag should be a semantic version (e.g., 5.1.0)"
  }

  # Verify local.forwarder_version is set
  assert {
    condition     = local.forwarder_version != null
    error_message = "local.forwarder_version should be set when using latest"
  }

  # Layer runtime should be set to the latest version of compatible_runtimes
  assert {
    condition     = aws_lambda_function.forwarder.runtime == "python3.14"
    error_message = "Lambda runtime should be python3.14"
  }
}

# Test with specific layer_version
run "version_tag_with_specific_layer" {
  command = plan

  variables {
    layer_version = "92"
  }

  override_data {
    target = data.aws_lambda_layer_version.this
    values = {
      compatible_runtimes = [
        "python3.13",
      ]
    }
  }

  # Lambda should have dd_forwarder_version tag
  assert {
    condition     = contains(keys(aws_lambda_function.forwarder.tags), "dd_forwarder_version")
    error_message = "Lambda function should have dd_forwarder_version tag when using specific layer version"
  }

  # Tag should be a semantic version
  assert {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", aws_lambda_function.forwarder.tags["dd_forwarder_version"]))
    error_message = "dd_forwarder_version tag should be a semantic version"
  }

  # Layer ARN should use the specified version
  assert {
    condition     = can(regex(":92$", aws_lambda_function.forwarder.layers[0]))
    error_message = "Lambda layer ARN should end with :92"
  }

  # Runtime should match the compatible_runtimes returned by the layer data source
  assert {
    condition     = aws_lambda_function.forwarder.runtime == "python3.13"
    error_message = "Lambda runtime should be python3.13"
  }
}

# Test that user tags are preserved alongside dd_forwarder_version
run "version_tag_with_user_tags" {
  command = plan

  variables {
    tags = {
      Environment = "test"
      Team        = "platform"
    }
  }

  # User tags should be present
  assert {
    condition     = aws_lambda_function.forwarder.tags["Environment"] == "test"
    error_message = "User-provided Environment tag should be preserved"
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["Team"] == "platform"
    error_message = "User-provided Team tag should be preserved"
  }

  # dd_forwarder_version should also be present
  assert {
    condition     = contains(keys(aws_lambda_function.forwarder.tags), "dd_forwarder_version")
    error_message = "dd_forwarder_version tag should be added alongside user tags"
  }
}
