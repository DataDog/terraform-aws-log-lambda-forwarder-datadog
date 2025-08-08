output "datadog_forwarder_arn" {
  description = "Datadog Forwarder Lambda Function ARN"
  value       = aws_lambda_function.forwarder.arn
}

output "datadog_forwarder_function_name" {
  description = "Datadog Forwarder Lambda Function Name"
  value       = aws_lambda_function.forwarder.function_name
}

output "datadog_forwarder_role_arn" {
  description = "Datadog Forwarder Lambda Function Role ARN"
  value       = aws_iam_role.forwarder_role.arn
}

output "datadog_forwarder_role_name" {
  description = "Datadog Forwarder Lambda Function Role Name"
  value       = aws_iam_role.forwarder_role.name
}

output "dd_api_key_secret_arn" {
  description = "ARN of SecretsManager Secret with Datadog API Key"
  value       = var.dd_api_key_secret_arn == "arn:aws:secretsmanager:DEFAULT" && var.dd_api_key_ssm_parameter_name == "" ? aws_secretsmanager_secret.dd_api_key_secret[0].arn : null
}

output "forwarder_bucket_name" {
  description = "Name of the S3 bucket used by the Forwarder"
  value       = local.create_s3_bucket ? aws_s3_bucket.forwarder_bucket[0].id : var.dd_forwarder_existing_bucket_name != "" ? var.dd_forwarder_existing_bucket_name : null
}

output "forwarder_bucket_arn" {
  description = "ARN of the S3 bucket used by the Forwarder"
  value       = local.create_s3_bucket ? aws_s3_bucket.forwarder_bucket[0].arn : null
}

output "forwarder_log_group_name" {
  description = "Name of the CloudWatch Log Group for the Forwarder"
  value       = aws_cloudwatch_log_group.forwarder_log_group.name
}

output "forwarder_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for the Forwarder"
  value       = aws_cloudwatch_log_group.forwarder_log_group.arn
}
