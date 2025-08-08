variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (datadoghq.com, datadoghq.eu, us3.datadoghq.com, us5.datadoghq.com, ap1.datadoghq.com, ap2.datadoghq.com, ddog-gov.com)"
  type        = string
  default     = "datadoghq.com"
}

variable "function_name" {
  description = "Name of the Datadog forwarder function"
  type        = string
  default     = "datadog-forwarder-vpc"
}

variable "memory_size" {
  description = "Memory size for the Lambda function"
  type        = number
  default     = 1024
}

variable "timeout" {
  description = "Timeout for the Lambda function"
  type        = number
  default     = 120
}

variable "create_vpc" {
  description = "Whether to create a new VPC or use an existing one"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID to use (required if create_vpc is false)"
  type        = string
  default     = ""
}

variable "security_group_name" {
  description = "Name of existing security group to use (required if create_vpc is false)"
  type        = string
  default     = ""
}

variable "proxy_url" {
  description = "HTTP proxy URL (optional)"
  type        = string
  default     = ""
}

variable "no_proxy" {
  description = "Comma-separated list of domains to exclude from proxy"
  type        = string
  default     = ""
}

variable "dd_tags" {
  description = "Tags to apply to forwarded logs"
  type        = string
  default     = "env:production,deployment:vpc,source:aws"
}
