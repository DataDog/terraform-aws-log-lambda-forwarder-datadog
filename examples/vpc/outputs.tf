output "forwarder_arn" {
  description = "ARN of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder.datadog_forwarder_arn
}

output "forwarder_function_name" {
  description = "Name of the Datadog Forwarder Lambda function"
  value       = module.datadog_forwarder.datadog_forwarder_function_name
}

output "vpc_id" {
  description = "VPC ID used by the forwarder"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used by the forwarder"
  value       = local.subnet_ids
}

output "security_group_ids" {
  description = "Security Group IDs used by the forwarder"
  value       = local.security_group_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs (if VPC was created)"
  value       = var.create_vpc ? aws_eip.nat[*].public_ip : []
}

output "forwarder_bucket_name" {
  description = "S3 bucket name used by the forwarder"
  value       = module.datadog_forwarder.forwarder_bucket_name
}