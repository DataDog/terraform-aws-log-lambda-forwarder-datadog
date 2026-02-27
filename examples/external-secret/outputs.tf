output "forwarder_arn" {
  description = "ARN of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder.datadog_forwarder_arn
}

output "forwarder_function_name" {
  description = "Name of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder.datadog_forwarder_function_name
}

output "external_secret_arn" {
  description = "ARN of the externally-managed Secrets Manager secret"
  value       = aws_secretsmanager_secret.dd_api_key.arn
}
