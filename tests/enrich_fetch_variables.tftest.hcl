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

  mock_data "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::existing-datadog-bucket"
    }
  }
}

variables {
  dd_api_key                        = "test-api-key-value"
  dd_site                           = "datadoghq.com"
  dd_forwarder_existing_bucket_name = "existing-datadog-bucket"
}

run "default" {
  command = plan
}

run "incompatible_s3" {
  command = plan

  variables {
    dd_enrich_s3_tags = true
    dd_fetch_s3_tags  = true
  }

  expect_failures = [
    var.dd_enrich_s3_tags,
  ]
}

run "ok_s3_enrich" {
  command = plan

  variables {
    dd_enrich_s3_tags = true
    dd_fetch_s3_tags  = false
  }
}

run "ok_s3_fetch" {
  command = plan

  variables {
    dd_enrich_s3_tags = false
    dd_fetch_s3_tags  = true
  }
}

run "incompatible_cloudwatch" {
  command = plan

  variables {
    dd_enrich_cloudwatch_tags = true
    dd_fetch_log_group_tags   = true
  }

  expect_failures = [
    var.dd_enrich_cloudwatch_tags,
  ]
}

run "ok_cloudwatch_enrich" {
  command = plan

  variables {
    dd_enrich_cloudwatch_tags = true
    dd_fetch_log_group_tags   = false
  }
}

run "ok_cloudwatch_fetch" {
  command = plan

  variables {
    dd_enrich_cloudwatch_tags = false
    dd_fetch_log_group_tags   = true
  }
}
