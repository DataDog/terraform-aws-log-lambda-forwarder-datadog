# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Get latest layer version from GitHub releases when "latest" is specified
data "http" "latest_release" {
  count = var.layer_version == "latest" ? 1 : 0
  url   = "https://api.github.com/repos/DataDog/datadog-serverless-functions/releases/latest"

  request_headers = {
    Accept = "application/vnd.github.v3+json"
  }
}

# Local values
locals {
  # Extract layer version from GitHub release title: "aws-dd-forwarder-4.14.0 (Layer v89)" -> "89"
  layer_version = var.layer_version == "latest" ? regex("\\(Layer v([0-9]+)\\)", jsondecode(data.http.latest_release[0].response_body).name)[0] : var.layer_version

  # Determine if we need to create an S3 bucket for caching and failed events storage
  create_s3_bucket = (coalesce(var.dd_fetch_log_group_tags, false) || coalesce(var.dd_fetch_lambda_tags, false) || coalesce(var.dd_fetch_s3_tags, false) || coalesce(var.dd_store_failed_events, false)) && var.dd_forwarder_existing_bucket_name == null

  # Default layer ARN based on partition and region
  default_layer_arn = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${local.dd_account_id}:layer:Datadog-Forwarder:${local.layer_version}"

  # Account ID varies by partition
  dd_account_id = data.aws_partition.current.partition == "aws-us-gov" ? "002406178527" : "464622532012"

  # Static placeholder zip path for layer-based installation
  placeholder_zip_path = "${path.module}/placeholder.zip"

  # IAM role ARN - use module output if created, otherwise use provided ARN
  iam_role_arn = var.existing_iam_role_arn == null ? module.iam[0].iam_role_arn : var.existing_iam_role_arn

  # AWS Region
  region = coalesce(var.region, data.aws_region.current.region)
}
