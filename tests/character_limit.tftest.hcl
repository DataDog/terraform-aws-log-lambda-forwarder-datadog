# Test that character limits are respected
provider "aws" {
  region = "us-east-1"
}

variables {
  function_name = "very-long-function-name-that-will-end-up-being-longer-than-sixtyfour-chars"
  partition     = "aws"
  iam_role_path = "/"
  account_id    = "123456789012"
}

run "character_limit_test" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    region = "us-east-1"
  }

  assert {
    condition     = length(aws_iam_role.forwarder_role.name) == 64
    error_message = "IAM role name is not trimmed down to exactly 64 characters"
  }

  assert {
    condition     = endswith(aws_iam_role.forwarder_role.name, "-us-east-1-Role")
    error_message = "IAM role does not have the correct suffix"
  }
}

run "character_limit_test_longer_region" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    region = "ap-southeast-1"
  }

  assert {
    condition     = length(aws_iam_role.forwarder_role.name) == 64
    error_message = "IAM role name is not trimmed down to exactly 64 characters"
  }

  assert {
    condition     = endswith(aws_iam_role.forwarder_role.name, "-ap-southeast-1-Role")
    error_message = "IAM role does not have the correct suffix"
  }
}
