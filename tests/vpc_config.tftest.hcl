# Test VPC configuration of the Datadog Forwarder module
provider "aws" {
  region = "us-east-1"
}

variables {
  dd_api_key             = "test-api-key-value"
  dd_site                = "datadoghq.com"
  dd_use_vpc             = true
  vpc_security_group_ids = ["sg-12345678"]
  vpc_subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  dd_http_proxy_url      = "http://proxy.example.com:8080"
}

run "vpc_configuration_test" {
  command = plan

  # Test VPC configuration is applied
  assert {
    condition     = length(aws_lambda_function.forwarder.vpc_config) == 1
    error_message = "VPC configuration should be set when dd_use_vpc is true"
  }

  assert {
    condition     = contains(aws_lambda_function.forwarder.vpc_config[0].security_group_ids, "sg-12345678")
    error_message = "Security group IDs should be configured correctly"
  }

  assert {
    condition     = contains(aws_lambda_function.forwarder.vpc_config[0].subnet_ids, "subnet-12345678")
    error_message = "Subnet IDs should be configured correctly"
  }
}
