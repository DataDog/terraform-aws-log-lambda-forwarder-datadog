# Test that AWSLambdaVPCAccessExecutionRole is attached only when dd_use_vpc is true
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

# Test: Default (no VPC) - the VPC access managed policy is not attached
run "vpc_access_not_attached_by_default" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    function_name = "TestForwarder"
    iam_role_path = "/"
    partition     = "aws"
    region        = "us-east-1"
    account_id    = "123456789012"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.lambda_vpc_access) == 0
    error_message = "AWSLambdaVPCAccessExecutionRole should not be attached when dd_use_vpc is false"
  }
}

# Test: VPC forwarder - the VPC access managed policy is attached
run "vpc_access_attached_when_dd_use_vpc" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    function_name = "TestForwarder"
    iam_role_path = "/"
    partition     = "aws"
    region        = "us-east-1"
    account_id    = "123456789012"
    dd_use_vpc    = true
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.lambda_vpc_access) == 1
    error_message = "AWSLambdaVPCAccessExecutionRole should be attached when dd_use_vpc is true"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.lambda_vpc_access[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    error_message = "The VPC access attachment should use the AWSLambdaVPCAccessExecutionRole managed policy"
  }
}
