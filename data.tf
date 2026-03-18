# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local values
locals {
  # Determine layer version from explicit input or layer ARN
  layer_version = var.layer_version != null ? var.layer_version : regex("[0-9]+$", var.layer_arn)

  # Determine if we need to create an S3 bucket for caching and failed events storage
  create_s3_bucket = (coalesce(var.dd_fetch_log_group_tags, false) || coalesce(var.dd_fetch_lambda_tags, false) || coalesce(var.dd_fetch_s3_tags, false) || (coalesce(var.dd_store_failed_events, false) && var.dd_sqs_queue_url == null)) && var.dd_forwarder_existing_bucket_name == null

  # SQS queue ARN derived from URL for IAM policy
  # URL format: https://sqs.{region}.amazonaws.com/{account_id}/{queue_name}
  sqs_queue_arn = var.dd_sqs_queue_url != null ? "arn:${data.aws_partition.current.partition}:sqs:${regex("https://sqs\\.([a-z0-9-]+)\\.amazonaws\\.com", var.dd_sqs_queue_url)[0]}:${split("/", var.dd_sqs_queue_url)[3]}:${split("/", var.dd_sqs_queue_url)[4]}" : null

  # Whether failed events storage is enabled (via S3 or SQS)
  store_failed_events_enabled = var.dd_sqs_queue_url != null || (coalesce(var.dd_store_failed_events, false) && (local.create_s3_bucket || var.dd_forwarder_existing_bucket_name != null))

  # Account ID varies by partition
  dd_account_id = data.aws_partition.current.partition == "aws-us-gov" ? "002406178527" : "464622532012"

  # Static placeholder zip path for layer-based installation
  placeholder_zip_path = "${path.module}/placeholder.zip"

  # IAM role ARN - use module output if created, otherwise use provided ARN
  iam_role_arn = var.existing_iam_role_arn == null ? module.iam[0].iam_role_arn : var.existing_iam_role_arn

  # AWS Region
  region = coalesce(var.region, data.aws_region.current.region)

  # Default layer ARN based on partition and region
  default_layer_arn = "arn:${data.aws_partition.current.partition}:lambda:${local.region}:${local.dd_account_id}:layer:Datadog-Forwarder:${local.layer_version}"

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

  tags_with_version = var.tags
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
