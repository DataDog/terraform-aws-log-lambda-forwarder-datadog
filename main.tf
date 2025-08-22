# IAM role and policies for the Forwarder Lambda
module "iam" {
  count = var.existing_iam_role_arn == "" ? 1 : 0
  
  source = "./modules/iam"

  function_name                       = var.function_name
  iam_role_path                      = var.iam_role_path
  permissions_boundary_arn           = var.permissions_boundary_arn
  partition                          = data.aws_partition.current.partition
  tags                               = var.tags
  s3_bucket_permissions              = var.dd_forwarder_existing_bucket_name != "" || local.create_s3_bucket
  forwarder_bucket_arn               = local.create_s3_bucket ? aws_s3_bucket.forwarder_bucket[0].arn : ""
  dd_forwarder_existing_bucket_name  = var.dd_forwarder_existing_bucket_name
  dd_api_key_ssm_parameter_name      = var.dd_api_key_ssm_parameter_name
  dd_api_key_secret_arn              = var.dd_api_key_secret_arn == "arn:aws:secretsmanager:REPLACEME" ? try(aws_secretsmanager_secret.dd_api_key_secret[0].arn, "") : "${var.dd_api_key_secret_arn}*"
  dd_fetch_lambda_tags               = var.dd_fetch_lambda_tags
  dd_fetch_step_functions_tags       = var.dd_fetch_step_functions_tags
  dd_fetch_log_group_tags            = var.dd_fetch_log_group_tags
  dd_use_vpc                         = var.dd_use_vpc
  additional_target_lambda_arns      = var.additional_target_lambda_arns
}

# Secrets Manager secret for Datadog API key
resource "aws_secretsmanager_secret" "dd_api_key_secret" {
  count = var.dd_api_key_secret_arn == "arn:aws:secretsmanager:REPLACEME" && var.dd_api_key_ssm_parameter_name == "" ? 1 : 0

  name_prefix = "DatadogAPIKey-${var.function_name}"

  description = "Datadog API Key"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "dd_api_key_secret_version" {
  count = var.dd_api_key_secret_arn == "arn:aws:secretsmanager:REPLACEME" && var.dd_api_key_ssm_parameter_name == "" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.dd_api_key_secret[0].id
  secret_string = var.dd_api_key
}

# S3 bucket for the forwarder (if needed)
resource "aws_s3_bucket" "forwarder_bucket" {
  count = local.create_s3_bucket ? 1 : 0

  bucket = var.dd_forwarder_bucket_name != "" ? var.dd_forwarder_bucket_name : null

  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "forwarder_bucket_encryption" {
  count = local.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.forwarder_bucket[0].id

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "forwarder_bucket_pab" {
  count = local.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.forwarder_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "forwarder_bucket_logging" {
  count = var.dd_forwarder_buckets_access_logs_target != "" ? 1 : 0

  bucket = aws_s3_bucket.forwarder_bucket[0].id

  target_bucket = var.dd_forwarder_buckets_access_logs_target
  target_prefix = "datadog-forwarder/"
}

resource "aws_s3_bucket_lifecycle_configuration" "forwarder_bucket_lifecycle" {
  count = local.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.forwarder_bucket[0].id

  rule {
    id     = "delete-incomplete-mpu-7days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 bucket policy
resource "aws_s3_bucket_policy" "forwarder_bucket_policy" {
  count = local.create_s3_bucket ? 1 : 0

  bucket = aws_s3_bucket.forwarder_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSLRequestsOnly"
        Effect = "Deny"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.forwarder_bucket[0].arn,
          "${aws_s3_bucket.forwarder_bucket[0].arn}/*"
        ]
        Principal = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "forwarder" {
  depends_on = [terraform_data.download_forwarder_zip, terraform_data.create_temp_zip]

  function_name = var.function_name != "DatadogForwarder" ? var.function_name : null
  description   = "Pushes logs, metrics and traces from AWS to Datadog."
  role          = local.iam_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  memory_size   = var.memory_size
  timeout       = var.timeout

  # Use layer or local zip file
  layers = var.install_as_layer ? [
    var.layer_arn != "" ? var.layer_arn : local.default_layer_arn
  ] : null

  # Local zip file when not using layers
  filename = var.install_as_layer ? local.temp_zip_path : local.forwarder_zip_path

  # Ensure Lambda updates when source code changes
  source_code_hash = var.install_as_layer ? null : filebase64sha256(local.forwarder_zip_path)

  reserved_concurrent_executions = var.reserved_concurrency != "" ? tonumber(var.reserved_concurrency) : null

  dynamic "vpc_config" {
    for_each = var.dd_use_vpc ? [1] : []

    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  environment {
    variables = merge(
      {
        DD_SITE                   = var.dd_site
        DD_TAGS_CACHE_TTL_SECONDS = tostring(var.tags_cache_ttl_seconds)
        DD_FETCH_S3_TAGS          = tostring(var.dd_fetch_s3_tags)
        DD_USE_VPC                = tostring(var.dd_use_vpc)
        DD_TRACE_ENABLED          = tostring(var.dd_trace_enabled)
        DD_ENHANCED_METRICS       = tostring(var.dd_enhanced_metrics)
      },
      # API key configuration
      var.dd_api_key_ssm_parameter_name != "" ? {
        DD_API_KEY_SSM_NAME = var.dd_api_key_ssm_parameter_name
        } : {
        DD_API_KEY_SECRET_ARN = var.dd_api_key_secret_arn == "arn:aws:secretsmanager:REPLACEME" ? aws_secretsmanager_secret.dd_api_key_secret[0].arn : var.dd_api_key_secret_arn
      },
      # S3 bucket name
      local.create_s3_bucket || var.dd_forwarder_existing_bucket_name != "" ? {
        DD_S3_BUCKET_NAME = local.create_s3_bucket ? aws_s3_bucket.forwarder_bucket[0].id : var.dd_forwarder_existing_bucket_name
      } : {},
      # Optional environment variables
      var.dd_tags != "" ? { DD_TAGS = var.dd_tags } : {},
      var.dd_fetch_lambda_tags ? { DD_FETCH_LAMBDA_TAGS = tostring(var.dd_fetch_lambda_tags) } : {},
      var.dd_fetch_log_group_tags ? { DD_FETCH_LOG_GROUP_TAGS = tostring(var.dd_fetch_log_group_tags) } : {},
      var.dd_fetch_step_functions_tags ? { DD_FETCH_STEP_FUNCTIONS_TAGS = tostring(var.dd_fetch_step_functions_tags) } : {},
      var.dd_no_ssl ? { DD_NO_SSL = tostring(var.dd_no_ssl) } : {},
      var.dd_url != "" ? { DD_URL = var.dd_url } : {},
      var.dd_port != "" ? { DD_PORT = var.dd_port } : {},
      var.dd_store_failed_events && (local.create_s3_bucket || var.dd_forwarder_existing_bucket_name != "") ? { DD_STORE_FAILED_EVENTS = tostring(var.dd_store_failed_events) } : {},
      var.redact_ip ? { REDACT_IP = tostring(var.redact_ip) } : {},
      var.redact_email ? { REDACT_EMAIL = tostring(var.redact_email) } : {},
      var.dd_scrubbing_rule != "" ? { DD_SCRUBBING_RULE = var.dd_scrubbing_rule } : {},
      var.dd_scrubbing_rule_replacement != "" ? { DD_SCRUBBING_RULE_REPLACEMENT = var.dd_scrubbing_rule_replacement } : {},
      var.exclude_at_match != "" ? { EXCLUDE_AT_MATCH = var.exclude_at_match } : {},
      var.include_at_match != "" ? { INCLUDE_AT_MATCH = var.include_at_match } : {},
      var.dd_multiline_log_regex_pattern != "" ? { DD_MULTILINE_LOG_REGEX_PATTERN = var.dd_multiline_log_regex_pattern } : {},
      var.dd_skip_ssl_validation ? { DD_SKIP_SSL_VALIDATION = tostring(var.dd_skip_ssl_validation) } : {},
      var.dd_forward_log == false ? { DD_FORWARD_LOG = tostring(var.dd_forward_log) } : {},
      var.dd_step_functions_trace_enabled ? { DD_STEP_FUNCTIONS_TRACE_ENABLED = tostring(var.dd_step_functions_trace_enabled) } : {},
      var.dd_use_compression == false ? { DD_USE_COMPRESSION = tostring(var.dd_use_compression) } : {},
      var.dd_compression_level != 6 ? { DD_COMPRESSION_LEVEL = tostring(var.dd_compression_level) } : {},
      var.dd_max_workers != 20 ? { DD_MAX_WORKERS = tostring(var.dd_max_workers) } : {},
      var.dd_http_proxy_url != "" ? {
        HTTP_PROXY  = var.dd_http_proxy_url
        HTTPS_PROXY = var.dd_http_proxy_url
      } : {},
      var.dd_no_proxy != "" ? { NO_PROXY = var.dd_no_proxy } : {},
      length(var.additional_target_lambda_arns) > 0 ? { DD_ADDITIONAL_TARGET_LAMBDAS = join(",", var.additional_target_lambda_arns) } : {},
      var.dd_api_url != "" ? { DD_API_URL = var.dd_api_url } : {},
      var.dd_trace_intake_url != "" ? { DD_TRACE_INTAKE_URL = var.dd_trace_intake_url } : {},
      var.dd_log_level != "" ? { DD_LOG_LEVEL = var.dd_log_level } : {}
    )
  }

  tags = var.tags
}

# Lambda permissions
resource "aws_lambda_permission" "cloudwatch_logs_invoke" {
  statement_id   = "CloudWatchLogsInvokePermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = data.aws_partition.current.partition == "aws-cn" ? "logs.amazonaws.com.cn" : "logs.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*:*"
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id   = "S3Permission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = "s3.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id   = "SNSPermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = "sns.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id   = "CloudWatchEventsPermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = data.aws_partition.current.partition == "aws-cn" ? "events.amazonaws.com.cn" : "events.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "forwarder_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.forwarder.function_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

# Download Lambda source from GitHub
resource "terraform_data" "download_forwarder_zip" {
  count = var.install_as_layer == false ? 1 : 0

  triggers_replace = {
    version = local.forwarder_version
  }

  provisioner "local-exec" {
    command = "curl -L -o ${local.forwarder_zip_path} ${local.source_zip_url}"
  }
}

# Create empty zip for layer-based installation
resource "terraform_data" "create_temp_zip" {
  count = var.install_as_layer ? 1 : 0

  provisioner "local-exec" {
    command = "echo ' ' | zip -q ${local.temp_zip_path} -"
  }
}
