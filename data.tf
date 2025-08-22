# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# Local values
locals {
  forwarder_version = var.source_code_version
  layer_version     = var.layer_version

  # Determine if we need to create an S3 bucket for caching and failed events storage
  create_s3_bucket = (var.dd_fetch_log_group_tags || var.dd_fetch_lambda_tags || var.dd_store_failed_events) && var.dd_forwarder_existing_bucket_name == ""

  # Default layer ARN based on partition and region
  default_layer_arn = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${local.gov_cloud_account_id}:layer:Datadog-Forwarder:${local.layer_version}"

  # Account ID varies by partition
  gov_cloud_account_id = data.aws_partition.current.partition == "aws-us-gov" ? "002406178527" : "464622532012"

  # Source ZIP URL
  source_zip_url = "https://github.com/DataDog/datadog-serverless-functions/releases/download/aws-dd-forwarder-${local.forwarder_version}/aws-dd-forwarder-${local.forwarder_version}.zip"

  # Local file paths for ZIP handling
  forwarder_zip_path = "${path.module}/aws-dd-forwarder-${local.forwarder_version}.zip"
  temp_zip_path      = "${path.module}/temp.zip"

  # IAM role ARN - use module output if created, otherwise use provided ARN
  iam_role_arn = var.existing_iam_role_arn == "" ? module.iam[0].iam_role_arn : var.existing_iam_role_arn
}
