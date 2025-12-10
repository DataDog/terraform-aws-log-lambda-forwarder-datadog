# IAM role and policies for the Forwarder Lambda
module "iam" {
  count = var.existing_iam_role_arn == null ? 1 : 0

  source = "./modules/iam"

  function_name                     = var.function_name
  iam_role_path                     = var.iam_role_path
  permissions_boundary_arn          = var.permissions_boundary_arn
  partition                         = data.aws_partition.current.partition
  region                            = local.region
  tags                              = var.tags
  s3_bucket_permissions             = var.dd_forwarder_existing_bucket_name != null || local.create_s3_bucket
  forwarder_bucket_arn              = local.create_s3_bucket ? aws_s3_bucket.forwarder_bucket[0].arn : null
  dd_forwarder_existing_bucket_name = var.dd_forwarder_existing_bucket_name
  dd_api_key_ssm_parameter_name     = var.dd_api_key_ssm_parameter_name
  dd_api_key_secret_arn             = var.dd_api_key_secret_arn == null ? try(aws_secretsmanager_secret.dd_api_key_secret[0].arn, null) : "${var.dd_api_key_secret_arn}*"
  dd_fetch_lambda_tags              = var.dd_fetch_lambda_tags
  dd_fetch_step_functions_tags      = var.dd_fetch_step_functions_tags
  dd_fetch_log_group_tags           = var.dd_fetch_log_group_tags
  dd_fetch_s3_tags                  = var.dd_fetch_s3_tags
  dd_use_vpc                        = var.dd_use_vpc
  additional_target_lambda_arns     = var.additional_target_lambda_arns != null ? split(",", var.additional_target_lambda_arns) : []
}

# Secrets Manager secret for Datadog API key
resource "aws_secretsmanager_secret" "dd_api_key_secret" {
  count = var.dd_api_key_secret_arn == null && var.dd_api_key_ssm_parameter_name == null ? 1 : 0

  region = local.region

  name_prefix = "DatadogAPIKey-${var.function_name}"

  description = "Datadog API Key"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "dd_api_key_secret_version" {
  count = var.dd_api_key_secret_arn == null && var.dd_api_key_ssm_parameter_name == null ? 1 : 0

  region = local.region

  secret_id     = aws_secretsmanager_secret.dd_api_key_secret[0].id
  secret_string = var.dd_api_key
}

# S3 bucket for the forwarder (if needed)
resource "aws_s3_bucket" "forwarder_bucket" {
  count = local.create_s3_bucket ? 1 : 0

  region = local.region

  bucket = var.dd_forwarder_bucket_name != null ? var.dd_forwarder_bucket_name : null

  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "forwarder_bucket_encryption" {
  count = local.create_s3_bucket ? 1 : 0

  region = local.region

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

  region = local.region

  bucket = aws_s3_bucket.forwarder_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "forwarder_bucket_logging" {
  count = var.dd_forwarder_buckets_access_logs_target != null ? 1 : 0

  region = local.region

  bucket = aws_s3_bucket.forwarder_bucket[0].id

  target_bucket = var.dd_forwarder_buckets_access_logs_target
  target_prefix = "datadog-forwarder/"
}

resource "aws_s3_bucket_lifecycle_configuration" "forwarder_bucket_lifecycle" {
  count = local.create_s3_bucket ? 1 : 0

  region = local.region

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

  region = local.region

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
  region = local.region

  function_name = var.function_name
  description   = "Pushes logs, metrics and traces from AWS to Datadog."
  role          = local.iam_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  architectures = ["arm64"]
  memory_size   = var.memory_size
  timeout       = var.timeout

  # Use Lambda layer
  layers = [
    var.layer_arn != null ? var.layer_arn : local.default_layer_arn
  ]

  # Static placeholder zip file for layer-based installation
  filename = local.placeholder_zip_path

  reserved_concurrent_executions = var.reserved_concurrency != null ? tonumber(var.reserved_concurrency) : null

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
        DD_USE_VPC                = tostring(var.dd_use_vpc)
        DD_TRACE_ENABLED          = tostring(var.dd_trace_enabled)
      },
      # API key configuration
      var.dd_api_key_ssm_parameter_name != null ? {
        DD_API_KEY_SSM_NAME = var.dd_api_key_ssm_parameter_name
        } : {
        DD_API_KEY_SECRET_ARN = var.dd_api_key_secret_arn == null ? aws_secretsmanager_secret.dd_api_key_secret[0].arn : var.dd_api_key_secret_arn
      },
      # S3 bucket name
      local.create_s3_bucket || var.dd_forwarder_existing_bucket_name != null ? {
        DD_S3_BUCKET_NAME = local.create_s3_bucket ? aws_s3_bucket.forwarder_bucket[0].id : var.dd_forwarder_existing_bucket_name
      } : {},
      # Optional environment variables
      {
        DD_TAGS                         = var.dd_tags
        DD_ENRICH_S3_TAGS               = var.dd_enrich_s3_tags != null ? tostring(var.dd_enrich_s3_tags) : null
        DD_ENRICH_CLOUDWATCH_TAGS       = var.dd_enrich_cloudwatch_tags != null ? tostring(var.dd_enrich_cloudwatch_tags) : null
        DD_FETCH_LAMBDA_TAGS            = var.dd_fetch_lambda_tags != null ? tostring(var.dd_fetch_lambda_tags) : null
        DD_FETCH_LOG_GROUP_TAGS         = var.dd_fetch_log_group_tags != null ? tostring(var.dd_fetch_log_group_tags) : null
        DD_FETCH_S3_TAGS                = var.dd_fetch_s3_tags != null ? tostring(var.dd_fetch_s3_tags) : null
        DD_FETCH_STEP_FUNCTIONS_TAGS    = var.dd_fetch_step_functions_tags != null ? tostring(var.dd_fetch_step_functions_tags) : null
        DD_NO_SSL                       = var.dd_no_ssl
        DD_URL                          = var.dd_url
        DD_PORT                         = var.dd_port
        DD_STORE_FAILED_EVENTS          = coalesce(var.dd_store_failed_events, false) && (local.create_s3_bucket || var.dd_forwarder_existing_bucket_name != null) ? "true" : null
        REDACT_IP                       = var.redact_ip != null ? tostring(var.redact_ip) : null
        REDACT_EMAIL                    = var.redact_email != null ? tostring(var.redact_email) : null
        DD_SCRUBBING_RULE               = var.dd_scrubbing_rule
        DD_SCRUBBING_RULE_REPLACEMENT   = var.dd_scrubbing_rule_replacement
        EXCLUDE_AT_MATCH                = var.exclude_at_match
        INCLUDE_AT_MATCH                = var.include_at_match
        DD_MULTILINE_LOG_REGEX_PATTERN  = var.dd_multiline_log_regex_pattern
        DD_SKIP_SSL_VALIDATION          = var.dd_skip_ssl_validation != null ? tostring(var.dd_skip_ssl_validation) : null
        DD_FORWARD_LOG                  = var.dd_forward_log != null ? tostring(var.dd_forward_log) : null
        DD_STEP_FUNCTIONS_TRACE_ENABLED = var.dd_step_functions_trace_enabled != null ? tostring(var.dd_step_functions_trace_enabled) : null
        DD_USE_COMPRESSION              = var.dd_use_compression != null ? tostring(var.dd_use_compression) : null
        DD_ENHANCED_METRICS             = tostring(var.dd_enhanced_metrics)
        DD_COMPRESSION_LEVEL            = var.dd_compression_level
        DD_MAX_WORKERS                  = var.dd_max_workers
        HTTP_PROXY                      = var.dd_http_proxy_url
        HTTPS_PROXY                     = var.dd_http_proxy_url
        NO_PROXY                        = var.dd_no_proxy
        DD_ADDITIONAL_TARGET_LAMBDAS    = var.additional_target_lambda_arns
        DD_API_URL                      = var.dd_api_url
        DD_TRACE_INTAKE_URL             = var.dd_trace_intake_url
        DD_LOG_LEVEL                    = var.dd_log_level
      }
    )
  }

  tags = local.tags_with_version
}

# Lambda permissions
resource "aws_lambda_permission" "cloudwatch_logs_invoke" {
  region = local.region

  statement_id   = "CloudWatchLogsInvokePermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = data.aws_partition.current.partition == "aws-cn" ? "logs.amazonaws.com.cn" : "logs.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "arn:${data.aws_partition.current.partition}:logs:${local.region}:${data.aws_caller_identity.current.account_id}:log-group:*:*"
}

resource "aws_lambda_permission" "s3_invoke" {
  region = local.region

  statement_id   = "S3Permission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = "s3.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "sns_invoke" {
  region = local.region

  statement_id   = "SNSPermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = "sns.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  region = local.region

  statement_id   = "CloudWatchEventsPermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.forwarder.function_name
  principal      = data.aws_partition.current.partition == "aws-cn" ? "events.amazonaws.com.cn" : "events.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "forwarder_log_group" {
  region = local.region

  name              = "/aws/lambda/${aws_lambda_function.forwarder.function_name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}

# Scheduled retry

resource "aws_iam_role" "scheduled_retry" {
  count = coalesce(var.dd_store_failed_events, false) && coalesce(var.dd_schedule_retry_failed_events, false) ? 1 : 0

  name = "${var.function_name}-${local.region}-retry"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = data.aws_partition.current.partition == "aws-cn" ? "scheduler.amazonaws.com.cn" : "scheduler.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn != null ? var.permissions_boundary_arn : null

  tags = var.tags
}

resource "aws_iam_role_policy" "scheduled_retry" {
  count = coalesce(var.dd_store_failed_events, false) && coalesce(var.dd_schedule_retry_failed_events, false) ? 1 : 0

  name = "${var.function_name}-${local.region}-retry-policy"
  role = aws_iam_role.scheduled_retry[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction",
        ]
        Effect   = "Allow"
        Resource = aws_lambda_function.forwarder.arn
      },
    ]
  })
}

resource "aws_scheduler_schedule" "scheduled_retry" {
  count = coalesce(var.dd_store_failed_events, false) && coalesce(var.dd_schedule_retry_failed_events, false) ? 1 : 0

  name                = "${var.function_name}-${local.region}-retry"
  description         = "Retry the failed events from the Datadog Lambda Forwarder ${var.function_name}"
  schedule_expression = "rate(${var.dd_schedule_retry_interval} hours)"
  flexible_time_window {
    mode = "OFF"
  }
  target {
    arn      = aws_lambda_function.forwarder.arn
    role_arn = aws_iam_role.scheduled_retry[0].arn
    input    = jsonencode({ retry = true })
  }
}
