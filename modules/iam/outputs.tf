output "iam_role_arn" {
  description = "ARN of the IAM role for the Datadog Forwarder Lambda"
  value       = aws_iam_role.forwarder_role.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for the Datadog Forwarder Lambda"
  value       = aws_iam_role.forwarder_role.name
}

output "iam_role_id" {
  description = "ID of the IAM role for the Datadog Forwarder Lambda"
  value       = aws_iam_role.forwarder_role.id
}
