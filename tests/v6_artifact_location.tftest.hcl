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
  target = data.http.forwarder_versions[0]
  values = {
    response_body = "{\"latest\":{\"layer_version\":\"97\",\"forwarder_version\":\"5.3.0\"},\"mappings\":{\"92\":\"5.1.0\"}}"
  }
}

override_data {
  target = data.http.forwarder_zip_versions[0]
  values = {
    response_body = "{\"latest\":{\"forwarder_version\":\"6.0.0-rc.1\",\"release_date\":\"2026-09-15\"}}"
  }
}

run "zip_version_latest_resolves_through_manifest" {
  command = plan

  assert {
    condition     = length(data.http.forwarder_zip_versions) == 1
    error_message = "zip_version = \"latest\" must fetch the zip manifest to resolve it"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == "datadog-log-forwarder-us-east-1"
    error_message = "v6 bucket must default to datadog-log-forwarder-{region}"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1.zip"
    error_message = "v6 key must be derived from the resolved zip_version, not the literal \"latest\""
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["dd_forwarder_version"] == "6.0.0-rc.1"
    error_message = "v6 must tag the function with dd_forwarder_version"
  }
}

run "zip_bucket_follows_region" {
  command = plan

  variables {
    region = "eu-west-1"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == "datadog-log-forwarder-eu-west-1"
    error_message = "v6 bucket must follow local.region, not the provider region"
  }
}

run "zip_bucket_override" {
  command = plan

  variables {
    zip_bucket = "my-forwarder-mirror"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == "my-forwarder-mirror"
    error_message = "zip_bucket must override the derived bucket name"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.0-rc.1.zip"
    error_message = "overriding the bucket must not change the derived key"
  }
}

run "zip_version_pinned_skips_manifest" {
  command = plan

  variables {
    zip_version = "6.0.1"
  }

  assert {
    condition     = length(data.http.forwarder_zip_versions) == 0
    error_message = "a pinned zip_version must not fetch the zip manifest"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-6.0.1.zip"
    error_message = "a pinned zip_version must be used verbatim in the key"
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["dd_forwarder_version"] == "6.0.1"
    error_message = "a pinned zip_version must be used as dd_forwarder_version"
  }
}

run "zip_version_pinned_unknown_to_manifest" {
  command = plan

  variables {
    zip_version = "9.9.9"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_key == "aws-dd-forwarder-9.9.9.zip"
    error_message = "any pinned zip_version must drive the key without a manifest lookup"
  }

  assert {
    condition     = aws_lambda_function.forwarder.tags["dd_forwarder_version"] == "9.9.9"
    error_message = "a pinned zip_version must be tagged even when absent from the manifest"
  }
}
