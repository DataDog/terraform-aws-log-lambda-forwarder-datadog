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
  default     = "datadog-forwarder-basic"
}
