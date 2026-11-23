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
      region = "us-east-1"
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
  dd_site               = "datadoghq.com"
  region                = "us-east-1"
  dd_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-dd-key-AbCdEf"
  use_v6                = true
}

override_data {
  target = data.http.forwarder_zip_versions[0]
  values = {
    response_body = "{\"latest\":{\"forwarder_version\":\"6.0.0-rc.1\",\"release_date\":\"2026-09-15\"}}"
  }
}

run "fips_defaults_to_off_in_commercial" {
  command = plan

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1.zip"
    error_message = "fips must default to off (no -fips suffix) in the commercial partition"
  }
}

run "fips_true_in_eligible_region_uses_fips_artifact" {
  command = plan

  variables {
    fips = true
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1-fips.zip"
    error_message = "fips = true in us-east-1 must select the -fips artifact"
  }
}

run "fips_true_in_ineligible_region_is_rejected" {
  command = plan

  variables {
    fips   = true
    region = "eu-west-1"
  }

  expect_failures = [
    aws_lambda_function.forwarder,
  ]
}

run "fips_mandatory_in_govcloud_even_when_unset" {
  command = plan

  variables {
    region = "us-gov-west-1"
  }

  override_data {
    target = data.aws_partition.current
    values = {
      partition  = "aws-us-gov"
      dns_suffix = "amazonaws.com"
    }
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1-fips.zip"
    error_message = "fips must be forced on in aws-us-gov even when the variable is left unset"
  }
}

run "fips_false_in_govcloud_trips_the_warning_but_still_forces_fips" {
  command = plan

  variables {
    region = "us-gov-west-1"
    fips   = false
  }

  override_data {
    target = data.aws_partition.current
    values = {
      partition  = "aws-us-gov"
      dns_suffix = "amazonaws.com"
    }
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1-fips.zip"
    error_message = "fips = false must be ignored in aws-us-gov; the FIPS build must still be used"
  }

  expect_failures = [
    check.fips_mandatory_in_govcloud,
  ]
}
