# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Fetch GitHub releases to get forwarder version
data "http" "github_releases" {
  url = "https://api.github.com/repos/DataDog/datadog-serverless-functions/releases?per_page=100"

  request_headers = {
    Accept = "application/vnd.github.v3+json"
  }
}

# Local values
locals {
  # Parse GitHub releases (newest first)
  github_releases = jsondecode(data.http.github_releases.response_body)

  # Find target release: first one if "latest", otherwise search for matching layer version
  target_release = (
    var.layer_version == "latest"
    ? local.github_releases[0]
    : try([for r in local.github_releases : r if can(regex("\\(Layer v${var.layer_version}\\)", r.name))][0], null)
  )

  # Extract layer version from release name: "aws-dd-forwarder-5.1.0 (Layer v92)" -> "92"
  layer_version = var.layer_version == "latest" ? regex("\\(Layer v([0-9]+)\\)", local.target_release.name)[0] : var.layer_version

  # Extract forwarder version from release name: "aws-dd-forwarder-5.1.0" -> "5.1.0"
  forwarder_version = local.target_release != null ? regex("aws-dd-forwarder-(.+)", local.target_release.tag_name)[0] : null

  # Determine if we need to create an S3 bucket for caching and failed events storage
  create_s3_bucket = (coalesce(var.dd_fetch_log_group_tags, false) || coalesce(var.dd_fetch_lambda_tags, false) || coalesce(var.dd_fetch_s3_tags, false) || coalesce(var.dd_store_failed_events, false)) && var.dd_forwarder_existing_bucket_name == null

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

  # Merge dd_forwarder_version tag with user-provided tags (only when version is known)
  tags_with_version = merge(
    var.tags,
    local.forwarder_version != null ? {
      dd_forwarder_version = local.forwarder_version
    } : {}
  )
}
