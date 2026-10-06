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

run "v5_loads_code_from_layer" {
  command = plan

  assert {
    condition     = aws_lambda_function.forwarder.handler == "lambda_function.lambda_handler"
    error_message = "v5 handler must be lambda_function.lambda_handler"
  }

  assert {
    condition     = startswith(aws_lambda_function.forwarder.runtime, "python")
    error_message = "v5 runtime must be a python runtime"
  }

  assert {
    condition     = anytrue([for l in aws_lambda_function.forwarder.layers : strcontains(l, "layer:Datadog-Forwarder:")])
    error_message = "v5 must attach the Datadog-Forwarder layer"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket == null && aws_lambda_function.forwarder.s3_key == null
    error_message = "v5 must load code from the layer placeholder, not from S3"
  }

  assert {
    condition     = length(data.http.forwarder_zip_versions) == 0
    error_message = "v5 must not fetch the zip version manifest"
  }
}

run "v6_loads_code_from_s3_zip" {
  command = plan

  variables {
    use_v6 = true
  }

  assert {
    condition     = aws_lambda_function.forwarder.runtime == "provided.al2023"
    error_message = "v6 runtime must be provided.al2023"
  }

  assert {
    condition     = aws_lambda_function.forwarder.handler == "bootstrap"
    error_message = "v6 handler must be bootstrap"
  }

  assert {
    condition     = aws_lambda_function.forwarder.s3_bucket != null && aws_lambda_function.forwarder.s3_key != null
    error_message = "v6 must load code from S3"
  }

  assert {
    condition     = aws_lambda_function.forwarder.filename == null
    error_message = "v6 must not set filename (code comes from S3, not the placeholder zip)"
  }

  assert {
    condition     = length(aws_lambda_function.forwarder.layers) == 0
    error_message = "v6 must not attach the Datadog-Forwarder layer (only user-supplied additional_layers)"
  }

  assert {
    condition     = length(data.http.forwarder_versions) == 0
    error_message = "v6 must not fetch the layer version manifest"
  }
}

run "v6_keeps_additional_layers" {
  command = plan

  variables {
    use_v6            = true
    additional_layers = ["arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Extension-ARM:83"]
  }

  assert {
    condition = length(aws_lambda_function.forwarder.layers) == 1 && contains(
      aws_lambda_function.forwarder.layers,
      "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Extension-ARM:83"
    )
    error_message = "v6 must attach additional_layers and nothing else"
  }
}
