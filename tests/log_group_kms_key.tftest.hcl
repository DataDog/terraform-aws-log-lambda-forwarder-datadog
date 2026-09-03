# Test log group KMS key encryption
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
  dd_api_key = "test-api-key-value"
  dd_site    = "datadoghq.com"
}

# Test: Default behavior - log group is not encrypted with a customer KMS key
run "default_log_group_has_no_kms_key" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.forwarder_log_group.kms_key_id == null
    error_message = "Log group should not have a KMS key set by default"
  }
}

# Test: Setting log_group_kms_key_arn encrypts the log group
run "log_group_kms_key_arn_sets_encryption" {
  command = plan

  variables {
    log_group_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  assert {
    condition     = aws_cloudwatch_log_group.forwarder_log_group.kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    error_message = "Log group should be encrypted with the provided KMS key"
  }
}

# Test: Setting log_group_kms_key_arn on the IAM module grants encrypt/decrypt permissions on that key
run "log_group_kms_key_arn_grants_iam_permissions" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    function_name         = "TestForwarder"
    iam_role_path         = "/"
    partition             = "aws"
    region                = "us-east-1"
    account_id            = "123456789012"
    log_group_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(aws_iam_role_policy.forwarder_policy.policy).Statement :
      contains(stmt.Action, "kms:Decrypt") && stmt.Resource == "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    ])
    error_message = "IAM policy should grant KMS permissions on the log group encryption key"
  }
}

# Test: A KMS alias ARN is also accepted
run "log_group_kms_key_arn_accepts_alias" {
  command = plan

  variables {
    log_group_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/my-log-group-key"
  }

  assert {
    condition     = aws_cloudwatch_log_group.forwarder_log_group.kms_key_id == "arn:aws:kms:us-east-1:123456789012:alias/my-log-group-key"
    error_message = "Log group should be encrypted with the provided KMS alias"
  }
}

# Test: A GovCloud partition ARN is accepted
run "log_group_kms_key_arn_accepts_govcloud_partition" {
  command = plan

  variables {
    log_group_kms_key_arn = "arn:aws-us-gov:kms:us-gov-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    region                = "us-gov-west-1"
  }

  assert {
    condition     = aws_cloudwatch_log_group.forwarder_log_group.kms_key_id == "arn:aws-us-gov:kms:us-gov-west-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    error_message = "Log group should be encrypted with the provided GovCloud KMS key"
  }
}

# Test: Validation rejects malformed ARNs
run "invalid_log_group_kms_key_arn_rejected" {
  command = plan

  variables {
    log_group_kms_key_arn = "not-a-valid-arn"
  }

  expect_failures = [
    var.log_group_kms_key_arn,
  ]
}

# Test: A key in a different region than the forwarder is rejected
run "log_group_kms_key_arn_cross_region_rejected" {
  command = plan

  variables {
    log_group_kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    region                = "us-east-1"
  }

  expect_failures = [
    aws_cloudwatch_log_group.forwarder_log_group,
  ]
}
