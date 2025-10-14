# Test multi-region support
provider "aws" {
  region = "us-east-1"
}

variables {
  dd_api_key             = "test-api-key-value"
  dd_site                = "datadoghq.com"
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
  command = apply
}

run "multi_region_us_east_2_existing_resources" {
  command = plan

  variables {
    region = "us-east-2"
  }
}
