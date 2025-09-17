output "forwarder_arn_us_east_1" {
  description = "ARN of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder_us_east_1.datadog_forwarder_arn
}

output "forwarder_function_name_us_east_1" {
  description = "Name of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder_us_east_1.datadog_forwarder_function_name
}

output "api_key_secret_arn_us_east_1" {
  description = "ARN of the Secrets Manager secret containing the Datadog API key"
  value       = module.datadog_forwarder_us_east_1.dd_api_key_secret_arn
}

output "forwarder_arn_us_east_2" {
  description = "ARN of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder_us_east_2.datadog_forwarder_arn
}

output "forwarder_function_name_us_east_2" {
  description = "Name of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder_us_east_2.datadog_forwarder_function_name
}

output "api_key_secret_arn_us_east_2" {
  description = "ARN of the Secrets Manager secret containing the Datadog API key"
  value       = module.datadog_forwarder_us_east_2.dd_api_key_secret_arn
}
