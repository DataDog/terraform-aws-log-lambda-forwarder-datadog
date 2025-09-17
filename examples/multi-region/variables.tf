variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site"
  type        = string
  default     = "datadoghq.com"
}

variable "function_name" {
  description = "Name of the Datadog forwarder function"
  type        = string
  default     = "datadog-forwarder-multi-region"
}
