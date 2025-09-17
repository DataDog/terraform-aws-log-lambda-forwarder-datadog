variable "function_name" {
  type        = string
  description = "The Datadog Forwarder Lambda function name"
}

variable "iam_role_path" {
  type        = string
  description = "Path for the IAM role"
}

variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "Permissions boundary ARN for the IAM role"
}

variable "partition" {
  type        = string
  description = "AWS partition (aws, aws-cn, aws-us-gov)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to the resource"
}

variable "s3_bucket_permissions" {
  type        = bool
  default     = false
  description = "Whether to include S3 bucket permissions for forwarder bucket"
}

variable "forwarder_bucket_arn" {
  type        = string
  default     = null
  description = "ARN of the forwarder S3 bucket"
}

variable "dd_forwarder_existing_bucket_name" {
  type        = string
  default     = null
  description = "Name of existing S3 bucket for forwarder"
}

variable "dd_api_key_ssm_parameter_name" {
  type        = string
  default     = null
  description = "SSM parameter name for Datadog API key"
}

variable "dd_api_key_secret_arn" {
  type        = string
  default     = null
  description = "ARN of the secret storing the Datadog API key"
}

variable "dd_fetch_lambda_tags" {
  type        = bool
  default     = null
  description = "Whether to fetch Lambda tags"
}

variable "dd_fetch_step_functions_tags" {
  type        = bool
  default     = null
  description = "Whether to fetch Step Functions tags"
}
variable "dd_fetch_s3_tags" {
  type        = bool
  default     = null
  description = "Whether to fetch S3 tags"
}
variable "dd_fetch_log_group_tags" {
  type        = bool
  default     = null
  description = "Whether to fetch Log Group tags"
}

variable "dd_use_vpc" {
  type        = bool
  default     = false
  description = "Whether Lambda uses VPC"
}

variable "additional_target_lambda_arns" {
  type        = list(string)
  default     = []
  description = "List of additional target Lambda ARNs"
}

variable "region" {
  type        = string
  description = "AWS region for resource naming"
}
