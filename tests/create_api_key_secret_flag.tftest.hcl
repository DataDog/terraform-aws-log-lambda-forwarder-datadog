# Tests for the create_dd_api_key_secret flag (fixes: Invalid count argument error, issue #8)
#
# The bug: when dd_api_key_secret_arn is set to a reference from a resource created in the
# same Terraform plan, the value is "unknown" at plan time. The old count expression:
#   count = var.dd_api_key_secret_arn == null ? 1 : 0
# cannot be evaluated when the value is unknown, causing "Invalid count argument".
#
# The fix: add create_dd_api_key_secret boolean flag to make this decision explicit at
# plan time, bypassing the unknown-value problem entirely.
#
# All tests here use mock_provider + override_data so they run without real AWS credentials.

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
      name = "us-east-1"
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
  dd_site = "datadoghq.com"
  region  = "us-east-1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario 1: explicit flag=false with dd_api_key_secret_arn (the main fix)
#
# Simulates the case where the secret ARN comes from a resource in the same plan.
# With the flag set explicitly, the count decision is made at plan time without
# evaluating the ARN value — bypassing the "Invalid count argument" error.
# ─────────────────────────────────────────────────────────────────────────────
run "explicit_false_with_secret_arn" {
  command = plan

  variables {
    dd_api_key_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-dd-key-AbCdEf"
    create_dd_api_key_secret = false
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "No secret should be created when create_dd_api_key_secret=false"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.dd_api_key_secret_version) == 0
    error_message = "No secret version should be created when create_dd_api_key_secret=false"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario 2: explicit flag=false with dd_api_key_ssm_parameter_name
# ─────────────────────────────────────────────────────────────────────────────
run "explicit_false_with_ssm_parameter" {
  command = plan

  variables {
    dd_api_key_ssm_parameter_name = "/datadog/api-key"
    create_dd_api_key_secret      = false
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "No secret should be created when using SSM parameter with flag=false"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario 3: explicit flag=true — forces secret creation
# ─────────────────────────────────────────────────────────────────────────────
run "explicit_true_creates_secret" {
  command = plan

  variables {
    dd_api_key               = "test-api-key-value"
    create_dd_api_key_secret = true
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 1
    error_message = "Secret should be created when create_dd_api_key_secret=true and dd_api_key is set"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario 4: null flag (default) — automatic detection (backward compat)
# ─────────────────────────────────────────────────────────────────────────────
run "null_flag_auto_creates_secret_from_api_key" {
  command = plan

  variables {
    dd_api_key = "test-api-key-value"
    # create_dd_api_key_secret not set (null/default)
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 1
    error_message = "Secret should be auto-created when dd_api_key is provided and flag is null"
  }
}

run "null_flag_auto_skips_secret_with_external_arn" {
  command = plan

  variables {
    dd_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:existing-key-XyZwAb"
    # create_dd_api_key_secret not set (null/default)
  }

  override_data {
    target = data.http.forwarder_versions
    values = {
      response_body = "{\"latest\":{\"layer_version\":\"92\",\"forwarder_version\":\"5.1.0\"},\"mappings\":{}}"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 0
    error_message = "Secret should NOT be auto-created when dd_api_key_secret_arn is provided"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Scenario 5: validation failures — ensure invalid configurations are rejected
# ─────────────────────────────────────────────────────────────────────────────

# flag=false requires an external ARN or SSM parameter — omitting both should fail validation
run "flag_false_without_arn_fails_validation" {
  command = plan

  variables {
    dd_api_key               = "test-api-key-value"
    create_dd_api_key_secret = false
    # No dd_api_key_secret_arn or dd_api_key_ssm_parameter_name
  }

  expect_failures = [
    var.create_dd_api_key_secret
  ]
}

# flag=true requires dd_api_key — omitting it should fail validation
run "flag_true_without_api_key_fails_validation" {
  command = plan

  variables {
    dd_api_key_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-key-AbCdEf"
    create_dd_api_key_secret = true
    # dd_api_key is NOT provided
  }

  expect_failures = [
    var.create_dd_api_key_secret
  ]
}

# Invalid Secrets Manager ARN format should be rejected
run "invalid_secret_arn_format_fails_validation" {
  command = plan

  variables {
    dd_api_key_secret_arn = "not-a-valid-arn"
  }

  expect_failures = [
    var.dd_api_key_secret_arn
  ]
}

# Invalid SSM parameter name (missing leading slash) should be rejected
run "invalid_ssm_parameter_name_fails_validation" {
  command = plan

  variables {
    dd_api_key_ssm_parameter_name = "no-leading-slash"
  }

  expect_failures = [
    var.dd_api_key_ssm_parameter_name
  ]
}
