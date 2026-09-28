# Test multi-region support
mock_provider "aws" {
  mock_data "aws_s3_object" {
    defaults = {
      body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{\"92\":\"5.1.0\"}}"
    }
  }

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
  dd_api_key = "test-api-key-value"
  dd_site    = "datadoghq.com"
}

run "multi_region_us_east_1" {
  command = plan

  # Test default region is set to the provider region (us-east-1)
  assert {
    condition     = local.region == "us-east-1"
    error_message = "The region should be us-east-1"
  }
}

run "multi_region_us_east_2" {
  command = plan

  variables {
    region = "us-east-2"
  }

  # Test that the region is overridden to us-east-2
  assert {
    condition     = local.region == "us-east-2"
    error_message = "The region should be us-east-2"
  }
}

# Simulate the creation of resources in us-east-1 and us-east-2 to make sure resources name do not conflict (IAM roles, etc.)
run "multi_region_us_east_1_existing_resources" {
  command = plan
}

run "multi_region_us_east_2_existing_resources" {
  command = plan

  variables {
    region = "us-east-2"
  }
}
