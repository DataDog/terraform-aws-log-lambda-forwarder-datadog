output "forwarder_arn" {
  description = "ARN of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder.datadog_forwarder_arn
}

output "forwarder_function_name" {
  description = "Name of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder.datadog_forwarder_function_name
}

output "api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Datadog API key"
  value       = module.datadog_forwarder.dd_api_key_secret_arn
}

output "success_message" {
  description = "Success message"
  value       = "Successfully created the Datadog Forwarder Lambda function! To send a test log, run the following command:\n\n aws logs put-log-events --log-group-name /aws/lambda/test-log-group-basic --log-stream-name test --log-events timestamp=$(date +%s000),message=\"Hello world\""
}
