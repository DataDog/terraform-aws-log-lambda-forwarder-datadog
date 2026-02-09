# Test S3 log bucket ARN restrictions on IAM policy
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

# Test: Default behavior - s3:GetObject should allow all buckets for backward compatibility
run "default_s3_log_access_allows_all" {
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
    condition = anytrue([
      for stmt in jsondecode(aws_iam_role_policy.forwarder_policy.policy).Statement :
      contains(stmt.Action, "s3:GetObject") && length(stmt.Action) == 1 && stmt.Resource == ["*"]
    ])
    error_message = "Default configuration should grant s3:GetObject on all resources ('*') for backward compatibility"
  }
}

# Test: Custom S3 log bucket ARNs should restrict the policy to specified buckets
run "custom_s3_log_access_restricts_buckets" {
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
    dd_s3_log_bucket_arns = [
      "arn:aws:s3:::my-log-bucket/*",
      "arn:aws:s3:::my-other-bucket/logs/*",
    ]
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(aws_iam_role_policy.forwarder_policy.policy).Statement :
      contains(stmt.Action, "s3:GetObject") && length(stmt.Action) == 1 &&
      contains(stmt.Resource, "arn:aws:s3:::my-log-bucket/*") &&
      contains(stmt.Resource, "arn:aws:s3:::my-other-bucket/logs/*") &&
      length(stmt.Resource) == 2
    ])
    error_message = "Custom dd_s3_log_bucket_arns should restrict s3:GetObject to the specified bucket ARNs only"
  }

  # Verify the wildcard is NOT present when custom ARNs are set
  assert {
    condition = !anytrue([
      for stmt in jsondecode(aws_iam_role_policy.forwarder_policy.policy).Statement :
      contains(stmt.Action, "s3:GetObject") && length(stmt.Action) == 1 && stmt.Resource == ["*"]
    ])
    error_message = "Custom dd_s3_log_bucket_arns should NOT grant s3:GetObject on all resources"
  }
}

# Test: Validation should reject invalid S3 ARNs
run "invalid_s3_log_bucket_arns_rejected" {
  command = plan

  variables {
    dd_api_key            = "test-api-key-value"
    dd_site               = "datadoghq.com"
    dd_s3_log_bucket_arns = ["not-a-valid-arn"]
  }

  expect_failures = [
    var.dd_s3_log_bucket_arns,
  ]
}
