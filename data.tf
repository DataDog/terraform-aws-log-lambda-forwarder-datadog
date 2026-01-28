# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Fetch version mapping from public S3 bucket
data "http" "forwarder_versions" {
  url = "https://datadog-opensource-asset-versions.s3.us-east-1.amazonaws.com/forwarder/versions.json"
}

# Local values
locals {
  # Parse version mapping from S3
  version_data = jsondecode(data.http.forwarder_versions.response_body)

  # Determine layer version: use latest or specified version
  layer_version = var.layer_version == "latest" ? local.version_data.latest.layer_version : var.layer_version

  # Determine forwarder version: use latest or lookup in mappings
  forwarder_version = (
    var.layer_version == "latest"
    ? local.version_data.latest.forwarder_version
    : lookup(local.version_data.mappings, var.layer_version, null)
  )

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

  # Merge dd_forwarder_version tag with user-provided tags (only when version is known)
  tags_with_version = merge(
    var.tags,
    local.forwarder_version != null ? {
      dd_forwarder_version = local.forwarder_version
    } : {}
  )
}
