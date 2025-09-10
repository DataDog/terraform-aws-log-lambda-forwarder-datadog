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
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Private subnet IDs used by the forwarder"
  value       = module.vpc.private_subnets
}

output "security_group_id" {
  description = "Security Group ID used by the forwarder"
  value       = aws_security_group.forwarder.id
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_public_ips
}

output "forwarder_bucket_name" {
  description = "S3 bucket name used by the forwarder"
  value       = module.datadog_forwarder.forwarder_bucket_name
}
