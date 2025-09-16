# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}


# Local values
locals {
  layer_version = var.layer_version

  # Determine if we need to create an S3 bucket for caching and failed events storage
  create_s3_bucket = ((var.dd_fetch_log_group_tags == "true") || (var.dd_fetch_lambda_tags == "true") || (var.dd_store_failed_events == "true")) && var.dd_forwarder_existing_bucket_name == null

  # Default layer ARN based on partition and region
  default_layer_arn = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${local.dd_account_id}:layer:Datadog-Forwarder:${local.layer_version}"

  # Account ID varies by partition
  dd_account_id = data.aws_partition.current.partition == "aws-us-gov" ? "002406178527" : "464622532012"

  # Temp zip path for layer-based installation
  temp_zip_path = "${path.cwd}/temp.zip"

  # IAM role ARN - use module output if created, otherwise use provided ARN
  iam_role_arn = var.existing_iam_role_arn == null ? module.iam[0].iam_role_arn : var.existing_iam_role_arn
}
