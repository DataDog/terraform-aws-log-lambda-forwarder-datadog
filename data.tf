# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Fetch version mapping from public S3 bucket
data "http" "forwarder_versions" {
  count = var.use_v6 ? 0 : 1

  url = "https://datadog-opensource-asset-versions.s3.us-east-1.amazonaws.com/forwarder/versions.json"
}

data "http" "forwarder_zip_versions" {
  count = local.resolve_zip_version_from_manifest ? 1 : 0

  url = "https://datadog-opensource-asset-versions.s3.us-east-1.amazonaws.com/forwarder/zip-versions.json"
}

# Local values
locals {
  resolve_zip_version_from_manifest = var.use_v6 && var.zip_version == "latest"

  layer_version_data = var.use_v6 ? null : jsondecode(data.http.forwarder_versions[0].response_body)
  zip_version_data   = local.resolve_zip_version_from_manifest ? jsondecode(data.http.forwarder_zip_versions[0].response_body) : null

  # Determine layer version: use latest or specified version
  layer_version = var.use_v6 ? null : (var.layer_version == "latest" ? local.layer_version_data.latest.layer_version : var.layer_version)

  # Determine zip version (starting from v6): use latest or specified version
  zip_version = var.use_v6 ? (local.resolve_zip_version_from_manifest ? local.zip_version_data.latest.forwarder_version : var.zip_version) : null

  # Determine forwarder version: use latest or lookup in mappings
  forwarder_version = (
    var.use_v6
    ? local.zip_version
    : (
      var.layer_version == "latest"
      ? local.layer_version_data.latest.forwarder_version
      : lookup(local.layer_version_data.mappings, var.layer_version, null)
    )
  )

  # Determine if we need to create an S3 bucket for caching and failed events storage.
  # Under v6 the bucket is created only for failed-events storage.
  create_s3_bucket = ((!var.use_v6 && (coalesce(var.dd_fetch_log_group_tags, false) || coalesce(var.dd_fetch_lambda_tags, false) || coalesce(var.dd_fetch_s3_tags, false))) || (coalesce(var.dd_store_failed_events, false) && var.dd_sqs_queue_url == null)) && var.dd_forwarder_existing_bucket_name == null

  # SQS queue ARN derived from URL for IAM policy
  # URL format: https://sqs.{region}.amazonaws.com/{account_id}/{queue_name}
  sqs_queue_arn = var.dd_sqs_queue_url != null ? "arn:${data.aws_partition.current.partition}:sqs:${regex("https://sqs\\.([a-z0-9-]+)\\.amazonaws\\.com", var.dd_sqs_queue_url)[0]}:${split("/", var.dd_sqs_queue_url)[3]}:${split("/", var.dd_sqs_queue_url)[4]}" : null

  # Whether failed events storage is enabled (via S3 or SQS)
  store_failed_events_enabled = var.dd_sqs_queue_url != null || (coalesce(var.dd_store_failed_events, false) && (local.create_s3_bucket || var.dd_forwarder_existing_bucket_name != null))

  # The forwarder's own bucket, whether module-created or supplied.
  s3_bucket_name = local.create_s3_bucket ? aws_s3_bucket.forwarder_bucket[0].id : var.dd_forwarder_existing_bucket_name

  dd_s3_bucket_name = var.use_v6 ? (local.store_failed_events_enabled ? local.s3_bucket_name : null) : local.s3_bucket_name

  # Account ID varies by partition
  dd_account_id = data.aws_partition.current.partition == "aws-us-gov" ? "002406178527" : "464622532012"

  # Static placeholder zip path for layer-based installation
  placeholder_zip_path = "${path.module}/placeholder.zip"

  # IAM role ARN - use module output if created, otherwise use provided ARN
  iam_role_arn = var.existing_iam_role_arn == null ? module.iam[0].iam_role_arn : var.existing_iam_role_arn

  # AWS Region
  region = coalesce(var.region, data.aws_region.current.region)

  # Default layer ARN based on partition and region
  default_layer_arn = var.use_v6 ? null : "arn:${data.aws_partition.current.partition}:lambda:${local.region}:${local.dd_account_id}:layer:Datadog-Forwarder:${local.layer_version}"

  # API Key Secret Management - detect usage patterns
  is_using_auto_secret_creation = var.dd_api_key != null && var.dd_api_key_secret_arn == null && var.dd_api_key_ssm_parameter_name == null
  has_external_secret_reference = var.dd_api_key_secret_arn != null || var.dd_api_key_ssm_parameter_name != null

  # Determine whether to create secret - respects explicit flag or falls back to automatic detection
  should_create_secret = var.create_dd_api_key_secret != null ? var.create_dd_api_key_secret : local.is_using_auto_secret_creation

  # Calculate effective secret ARN for IAM and Lambda usage
  effective_secret_arn = var.dd_api_key_ssm_parameter_name == null ? (
    local.should_create_secret ? try(aws_secretsmanager_secret.dd_api_key_secret[0].arn, null) :
    var.dd_api_key_secret_arn
  ) : null

  # Merge dd_forwarder_version tag with user-provided tags (only when version is known)
  tags_with_version = merge(
    var.tags,
    local.forwarder_version != null ? {
      dd_forwarder_version = local.forwarder_version
    } : {}
  )

  env_common = merge(
    var.dd_api_key_ssm_parameter_name != null ? {
      DD_API_KEY_SSM_NAME = var.dd_api_key_ssm_parameter_name
      } : {
      DD_API_KEY_SECRET_ARN = local.effective_secret_arn
    },
    {
      DD_SITE                         = var.dd_site
      DD_S3_BUCKET_NAME               = local.dd_s3_bucket_name
      DD_SOURCE                       = var.dd_source
      DD_TAGS                         = var.dd_tags
      DD_NO_SSL                       = var.dd_no_ssl
      DD_URL                          = var.dd_url
      DD_PORT                         = var.dd_port
      DD_SQS_QUEUE_URL                = var.dd_sqs_queue_url
      DD_SKIP_SSL_VALIDATION          = var.dd_skip_ssl_validation != null ? tostring(var.dd_skip_ssl_validation) : null
      DD_COMPRESSION_LEVEL            = var.dd_compression_level
      DD_SCRUBBING_RULE               = var.dd_scrubbing_rule
      DD_SCRUBBING_RULE_REPLACEMENT   = var.dd_scrubbing_rule_replacement
      REDACT_IP                       = var.redact_ip != null ? tostring(var.redact_ip) : null
      REDACT_EMAIL                    = var.redact_email != null ? tostring(var.redact_email) : null
      EXCLUDE_AT_MATCH                = var.exclude_at_match
      INCLUDE_AT_MATCH                = var.include_at_match
      DD_MULTILINE_LOG_REGEX_PATTERN  = var.dd_multiline_log_regex_pattern
      DD_STEP_FUNCTIONS_TRACE_ENABLED = var.dd_step_functions_trace_enabled != null ? tostring(var.dd_step_functions_trace_enabled) : null
      DD_ADDITIONAL_TARGET_LAMBDAS    = var.additional_target_lambda_arns
      DD_API_URL                      = var.dd_api_url
      DD_LOG_LEVEL                    = var.dd_log_level
      HTTP_PROXY                      = var.dd_http_proxy_url
      HTTPS_PROXY                     = var.dd_http_proxy_url
      NO_PROXY                        = var.dd_no_proxy
    }
  )

  env_prior_v6 = {
    DD_TAGS_CACHE_TTL_SECONDS = tostring(var.tags_cache_ttl_seconds)
    DD_USE_VPC                = tostring(var.dd_use_vpc)
    DD_TRACE_ENABLED          = tostring(var.dd_trace_enabled)
    DD_ENHANCED_METRICS       = tostring(var.dd_enhanced_metrics)
    DD_ENRICH_S3_TAGS         = var.dd_enrich_s3_tags != null ? tostring(var.dd_enrich_s3_tags) : null
    DD_ENRICH_CLOUDWATCH_TAGS = var.dd_enrich_cloudwatch_tags != null ? tostring(var.dd_enrich_cloudwatch_tags) : null
    DD_FETCH_LAMBDA_TAGS      = var.dd_fetch_lambda_tags != null ? tostring(var.dd_fetch_lambda_tags) : null
    DD_FETCH_LOG_GROUP_TAGS   = var.dd_fetch_log_group_tags != null ? tostring(var.dd_fetch_log_group_tags) : null
    DD_FETCH_S3_TAGS          = var.dd_fetch_s3_tags != null ? tostring(var.dd_fetch_s3_tags) : null
    DD_STORE_FAILED_EVENTS    = local.store_failed_events_enabled ? "true" : null
    DD_USE_COMPRESSION        = var.dd_use_compression != null ? tostring(var.dd_use_compression) : null
    DD_MAX_WORKERS            = var.dd_max_workers
    DD_FORWARD_LOG            = var.dd_forward_log != null ? tostring(var.dd_forward_log) : null
    DD_TRACE_INTAKE_URL       = var.dd_trace_intake_url
  }

  artifact_bucket = var.use_v6 ? coalesce(var.zip_bucket, "datadog-log-forwarder-${local.region}") : null
  artifact_key    = var.use_v6 ? "aws-dd-forwarder-${local.zip_version}.zip" : null
}

# Deprecation warnings for conflicting API key configurations.
# These will become hard validation errors in a future major release.
check "dd_api_key_not_used_with_secret_arn" {
  assert {
    condition     = var.dd_api_key == null || var.dd_api_key_secret_arn == null
    error_message = "DEPRECATED: dd_api_key and dd_api_key_secret_arn are both set. Only one API key approach should be used. Currently dd_api_key is being ignored in favor of dd_api_key_secret_arn. Remove dd_api_key to silence this warning. This will become an error in a future release."
  }
}

check "dd_api_key_not_used_with_ssm_parameter" {
  assert {
    condition     = var.dd_api_key == null || var.dd_api_key_ssm_parameter_name == null
    error_message = "DEPRECATED: dd_api_key and dd_api_key_ssm_parameter_name are both set. Only one API key approach should be used. Currently dd_api_key is being ignored in favor of dd_api_key_ssm_parameter_name. Remove dd_api_key to silence this warning. This will become an error in a future release."
  }
}

check "dd_secret_arn_not_used_with_ssm_parameter" {
  assert {
    condition     = var.dd_api_key_secret_arn == null || var.dd_api_key_ssm_parameter_name == null
    error_message = "DEPRECATED: dd_api_key_secret_arn and dd_api_key_ssm_parameter_name are both set. Only one API key approach should be used. Currently dd_api_key_secret_arn is being ignored in favor of dd_api_key_ssm_parameter_name. Remove dd_api_key_secret_arn to silence this warning. This will become an error in a future release."
  }
}

check "v6_unsupported_environment_variables_have_no_effect" {
  assert {
    condition     = !var.use_v6 || var.dd_fetch_lambda_tags == null
    error_message = "dd_fetch_lambda_tags has no effect with v6: tag enrichment is handled by the Datadog backend. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_fetch_log_group_tags == null
    error_message = "dd_fetch_log_group_tags has no effect with v6: tag enrichment is handled by the Datadog backend. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_fetch_s3_tags == null
    error_message = "dd_fetch_s3_tags has no effect with v6: tag enrichment is handled by the Datadog backend. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_enrich_s3_tags == null
    error_message = "dd_enrich_s3_tags has no effect with v6: tag enrichment is handled by the Datadog backend by default. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_enrich_cloudwatch_tags == null
    error_message = "dd_enrich_cloudwatch_tags has no effect with v6: tag enrichment is handled by the Datadog backend by default. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_use_compression == null
    error_message = "dd_use_compression has no effect with v6: set dd_compression_level to 0 to disable compression. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_max_workers == null
    error_message = "dd_max_workers has no effect with v6: concurrency is managed internally. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_forward_log == null
    error_message = "dd_forward_log has no effect with v6: it only forwards logs. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_trace_intake_url == null
    error_message = "dd_trace_intake_url has no effect with v6: it forwards logs only. Use the Datadog Lambda Extension for traces. Remove it to silence this warning."
  }
  assert {
    condition     = !var.use_v6 || var.dd_enhanced_metrics == false
    error_message = "dd_enhanced_metrics has no effect with v6: it forwards logs only. Use the Datadog Lambda Extension for enhanced metrics. Set it to false to silence this warning."
  }
}
