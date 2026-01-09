# Required variables
variable "dd_api_key" {
  type        = string
  default     = null
  description = <<-EOT
    The Datadog API key, which can be found from the APIs page (/account/settings#api).
    When provided, the module will automatically create and manage a Secrets Manager secret.

    NOTE: Do not use this with dd_api_key_secret_arn or dd_api_key_ssm_parameter_name.
    Choose ONE approach for API key management.
  EOT
  sensitive   = true
}

variable "dd_api_key_secret_arn" {
  type        = string
  default     = null
  description = <<-EOT
    The ARN of an existing secret storing the Datadog API key in AWS Secrets Manager.
    The secret must be stored as plaintext, not as a key-value pair.

    IMPORTANT: If you're creating this secret in the same Terraform plan, you'll encounter
    "Invalid count argument" errors. Solutions:
    1. Set create_dd_api_key_secret = false (recommended for same-plan creation)
    2. Create the secret in a separate Terraform state/plan
    3. Use a data source to reference a pre-existing secret
    4. Consider using dd_api_key instead (module creates secret automatically)

    NOTE: Do not use this with dd_api_key or dd_api_key_ssm_parameter_name.
  EOT

  validation {
    condition     = var.dd_api_key_secret_arn == null || can(regex("^arn:.*:secretsmanager:.*", var.dd_api_key_secret_arn))
    error_message = "dd_api_key_secret_arn must be a valid Secrets Manager ARN."
  }
}

variable "dd_api_key_ssm_parameter_name" {
  type        = string
  default     = null
  description = <<-EOT
    The name of an existing SSM Parameter Store parameter containing the Datadog API key.

    IMPORTANT: If you're creating this parameter in the same Terraform plan, you'll encounter
    "Invalid count argument" errors. Solutions:
    1. Set create_dd_api_key_secret = false (recommended for same-plan creation)
    2. Create the parameter in a separate Terraform state/plan
    3. Use a data source to reference a pre-existing parameter
    4. Consider using dd_api_key instead (module creates secret automatically)

    NOTE: Do not use this with dd_api_key or dd_api_key_secret_arn.
    When set, this takes precedence over secret-based configuration.
  EOT

  validation {
    condition     = var.dd_api_key_ssm_parameter_name == null || can(regex("^/[a-zA-Z0-9/_.-]*$", var.dd_api_key_ssm_parameter_name))
    error_message = "dd_api_key_ssm_parameter_name must match the pattern ^/[a-zA-Z0-9/_.-]*$."
  }
}

variable "create_dd_api_key_secret" {
  type        = bool
  default     = null
  description = <<-EOT
    Controls whether the module creates a Secrets Manager secret for the Datadog API key.
    - true: Force creation of secret (requires dd_api_key to be set)
    - false: Do not create secret (requires dd_api_key_secret_arn or dd_api_key_ssm_parameter_name)
    - null (default): Automatic behavior - create secret only if neither dd_api_key_secret_arn nor dd_api_key_ssm_parameter_name is provided

    Set this to false when using secrets/parameters created in the same Terraform plan to avoid "Invalid count argument" errors.
  EOT

  validation {
    condition     = var.create_dd_api_key_secret != true || var.dd_api_key != null
    error_message = "When create_dd_api_key_secret is true, dd_api_key must be provided."
  }

  validation {
    condition     = var.create_dd_api_key_secret != false || (var.dd_api_key_secret_arn != null || var.dd_api_key_ssm_parameter_name != null)
    error_message = "When create_dd_api_key_secret is false, either dd_api_key_secret_arn or dd_api_key_ssm_parameter_name must be provided."
  }
}

variable "dd_site" {
  type        = string
  default     = "datadoghq.com"
  description = "Define your Datadog Site to send data to."

  validation {
    condition     = contains(["datadoghq.com", "datadoghq.eu", "us3.datadoghq.com", "us5.datadoghq.com", "ap1.datadoghq.com", "ap2.datadoghq.com", "ddog-gov.com"], var.dd_site)
    error_message = "dd_site must be one of: datadoghq.com, datadoghq.eu, us3.datadoghq.com, us5.datadoghq.com, ap1.datadoghq.com, ap2.datadoghq.com, ddog-gov.com."
  }
}

# Lambda function configuration
variable "function_name" {
  type        = string
  default     = "DatadogForwarder"
  description = "The Datadog Forwarder Lambda function name. DO NOT change when updating an existing CloudFormation stack, otherwise the current forwarder function will be replaced and all the triggers will be lost."
}

variable "memory_size" {
  type        = number
  default     = 1024
  description = "Memory size for the Datadog Forwarder Lambda function"

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 3008
    error_message = "memory_size must be between 128 and 3008."
  }
}

variable "timeout" {
  type        = number
  default     = 120
  description = "Timeout for the Datadog Forwarder Lambda function"
}

variable "existing_iam_role_arn" {
  type        = string
  default     = null
  description = "ARN of existing IAM role to use for the Lambda function. If not provided, a new IAM role will be created."

  validation {
    condition = var.existing_iam_role_arn == null || (
      var.dd_forwarder_existing_bucket_name != null &&
      (var.dd_api_key_ssm_parameter_name != null || var.dd_api_key_secret_arn != null)
    )
    error_message = "When using existing_iam_role_arn, you must also specify dd_forwarder_existing_bucket_name and either dd_api_key_ssm_parameter_name or dd_api_key_secret_arn to avoid cross-region resource conflicts."
  }
}

variable "tags_cache_ttl_seconds" {
  type        = number
  default     = 300
  description = "TTL (in seconds) for the Datadog tags cache"
}

variable "reserved_concurrency" {
  type        = string
  default     = null
  description = "Reserved concurrency for the Datadog Forwarder Lambda function. If not set, use unreserved account concurrency. We recommend using at least 10 reserved concurrency, but default to 0 as you may need to increase your limits for this. If using unreserved account concurrency you may limit other lambda functions in your environment."

  validation {
    condition     = var.reserved_concurrency == null || can(tonumber(var.reserved_concurrency))
    error_message = "reserved_concurrency must be a valid integer number."
  }
}

variable "log_retention_in_days" {
  type        = number
  default     = 90
  description = "CloudWatch log retention for logs generated by the Datadog Forwarder Lambda function"
}

variable "layer_version" {
  type        = string
  default     = "latest"
  description = "Version of the Datadog Forwarder Lambda layer. Use 'latest' to automatically fetch the latest version from GitHub releases or specify a version like '89'."
}

variable "layer_arn" {
  type        = string
  default     = null
  description = "ARN for the layer containing the forwarder code. If empty, the script will use the version of the layer the forwarder was published with."
}

# Datadog configuration
variable "dd_tags" {
  type        = string
  default     = null
  description = "Add custom tags to forwarded logs. Comma-delimited string without trailing comma, e.g., env:prod,stack:classic"
}

variable "dd_source" {
  type        = string
  default     = null
  description = "Override the source attribute for all logs forwarded by Lambda Forwarder. By default, the Forwarder automatically detects the source based on the log origin (e.g., lambda, s3, cloudwatch, rds). When set, all logs will use the specified source value instead, and a source_overridden:true tag will be added to the logs."
}

variable "dd_enrich_s3_tags" {
  type        = bool
  default     = null
  description = "Instructs the Datadog backend to automatically enrich logs originating from S3 buckets with the tags associated with those buckets. This approach offers the same tag enrichment as `dd_fetch_s3_tags` but defers the operation after log ingestion, reducing Forwarder overhead. Requires Resource Collection to be enabled in your AWS integration. Require Lambda Forwarder v5."

  validation {
    condition     = !coalesce(var.dd_enrich_s3_tags, false) || !coalesce(var.dd_fetch_s3_tags, false)
    error_message = "S3 Tag enrichment cannot be enabled along side S3 Tag fetch from the forwarder"
  }
}

variable "dd_enrich_cloudwatch_tags" {
  type        = bool
  default     = null
  description = "Instructs the Datadog backend to automatically enrich logs originating from CloudWatch LogGroups with the tags associated with those log groups. This approach offers the same tag enrichment as `dd_fetch_log_group_tags` but defers the operation after log ingestion, reducing Forwarder overhead. Requires Resource Collection to be enabled in your AWS integration. Require Lambda Forwarder v5."

  validation {
    condition     = !coalesce(var.dd_enrich_cloudwatch_tags, false) || !coalesce(var.dd_fetch_log_group_tags, false)
    error_message = "Cloudwatch Tag enrichment cannot be enabled along side LogGroup Tag fetch from the forwarder"
  }
}

variable "dd_fetch_lambda_tags" {
  type        = bool
  default     = null
  description = "Let the forwarder fetch Lambda tags using GetResources API calls and apply them to logs, metrics and traces. If set to true, permission tag:GetResources will be automatically added to the Lambda execution IAM role."
}

variable "dd_fetch_log_group_tags" {
  type        = bool
  default     = null
  description = "(deprecated in favor of dd_enrich_cloudwatch_tags) Let the forwarder fetch Log Group tags using ListTagsForResource and apply them to logs, metrics and traces. If set to true, permission logs:ListTagsForResource will be automatically added to the Lambda execution IAM role."
}

variable "dd_fetch_step_functions_tags" {
  type        = bool
  default     = null
  description = "Let the forwarder fetch Step Functions tags using GetResources API calls and apply them to logs, metrics and traces. If set to true, permission tag:GetResources will be automatically added to the Lambda execution IAM role."
}

variable "dd_fetch_s3_tags" {
  type        = bool
  default     = null
  description = "(deprecated in favor of dd_enrich_s3_tags) Let the forwarder fetch S3 buckets tags using GetResources API calls and apply them to S3 based logs. If set to true, permission tag:GetResources will be automatically added to the Lambda execution IAM role."
}

# Network configuration
variable "dd_no_ssl" {
  type        = string
  default     = null
  description = "Disable SSL when forwarding logs, set to 'true' when forwarding logs through a proxy."
}

variable "dd_url" {
  type        = string
  default     = null
  description = "The endpoint URL to forward the logs to, useful for forwarding logs through a proxy"
}

variable "dd_port" {
  type        = string
  default     = null
  description = "The endpoint port to forward the logs to, useful for forwarding logs through a proxy"
}

variable "dd_skip_ssl_validation" {
  type        = bool
  default     = null
  description = "Send logs over HTTPS, while NOT validating the certificate provided by the endpoint. This will still encrypt the traffic between the forwarder and the log intake endpoint, but will not verify if the destination SSL certificate is valid. Set to true to skip SSL validation."
}

# Log processing
variable "redact_ip" {
  type        = bool
  default     = null
  description = "Replace text matching \\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3} with xxx.xxx.xxx.xxx. Set to 'true' to enable."
}

variable "redact_email" {
  type        = bool
  default     = null
  description = "Replace text matching [a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+ with xxxxx@xxxxx.com. Set to 'true' to enable."
}

variable "dd_scrubbing_rule" {
  type        = string
  default     = null
  description = "Replace text matching the supplied regular expression with xxxxx (default) or dd_scrubbing_rule_replacement (if supplied). Log scrubbing rule is applied to the full JSON-formatted log, including any metadata that is automatically added by the Lambda function."
}

variable "dd_scrubbing_rule_replacement" {
  type        = string
  default     = null
  description = "Replace text matching dd_scrubbing_rule with the supplied text"
}

variable "exclude_at_match" {
  type        = string
  default     = null
  description = "DO NOT send logs matching the supplied regular expression. If a log matches both the exclude_at_match and include_at_match, it is excluded. Filtering rules are applied to the full JSON-formatted log, including any metadata that is automatically added by the function."
}

variable "include_at_match" {
  type        = string
  default     = null
  description = "Only send logs matching the supplied regular expression and not excluded by exclude_at_match."
}

variable "dd_multiline_log_regex_pattern" {
  type        = string
  default     = null
  description = "Use the supplied regular expression to detect for a new log line for multiline logs from S3, e.g., use expression \"\\d{2}\\/\\d{2}\\/\\d{4}\" for multiline logs beginning with pattern \"11/10/2014\"."
}

variable "dd_forward_log" {
  type        = bool
  default     = null
  description = "Set to false to disable log forwarding, while continuing to forward other observability data, such as metrics and traces from Lambda functions."
}

variable "dd_step_functions_trace_enabled" {
  type        = bool
  default     = null
  description = "Set to true to enable tracing for all Step Functions."
}

variable "dd_use_compression" {
  type        = bool
  default     = null
  description = "Set to false to disable log compression. Only valid when sending logs over HTTP."
}

variable "dd_enhanced_metrics" {
  type        = bool
  default     = false
  description = "Set to true to enable enhanced Lambda metrics. This will generate additional custom metrics for Lambda functions, including cold starts, estimated AWS costs, and custom tags. Default is false."
}

# VPC configuration
variable "dd_use_vpc" {
  type        = bool
  default     = false
  description = "Set to true to deploy the Forwarder to a VPC and send logs, metrics, and traces via a proxy. When set to true, must also set vpc_security_group_ids and vpc_subnet_ids."
}

variable "dd_http_proxy_url" {
  type        = string
  default     = null
  description = "Sets the standard web proxy environment variables HTTP_PROXY and HTTPS_PROXY. These are the url endpoints your proxy server exposes. Make sure to also set dd_skip_ssl_validation to true."
}

variable "dd_no_proxy" {
  type        = string
  default     = null
  description = "Sets the standard web proxy environment variable NO_PROXY. It is a comma-separated list of domain names that should be excluded from the web proxy."
}

variable "vpc_security_group_ids" {
  type        = list(string)
  default     = []
  description = "List of VPC Security Group IDs. Used when dd_use_vpc is enabled."

  validation {
    condition     = var.dd_use_vpc == false || length(var.vpc_security_group_ids) > 0
    error_message = "vpc_security_group_ids must be specified when dd_use_vpc is true."
  }
}

variable "vpc_subnet_ids" {
  type        = list(string)
  default     = []
  description = "List of VPC Subnet IDs. Used when dd_use_vpc is enabled."

  validation {
    condition     = var.dd_use_vpc == false || length(var.vpc_subnet_ids) > 0
    error_message = "vpc_subnet_ids must be specified when dd_use_vpc is true."
  }
}

# Advanced configuration
variable "dd_compression_level" {
  type        = string
  default     = null
  nullable    = true
  description = "Set the compression level from 0 (no compression) to 9 (best compression) when sending logs."

  validation {
    condition = var.dd_compression_level == null ? true : (
      can(tonumber(var.dd_compression_level)) &&
      tonumber(var.dd_compression_level) >= 0 &&
      tonumber(var.dd_compression_level) <= 9
    )
    error_message = "dd_compression_level must be a number between 0 and 9."
  }
}

variable "dd_max_workers" {
  type        = string
  default     = null
  description = "Set the max number of workers sending logs concurrently."
}

variable "iam_role_path" {
  type        = string
  default     = "/"
  description = "The path for the IAM roles."
}

variable "permissions_boundary_arn" {
  type        = string
  default     = null
  description = "ARN for the Permissions Boundary Policy"
}

variable "additional_target_lambda_arns" {
  type        = string
  default     = null
  description = "Comma-separated list of lambda ARNs that get invoked asynchronously with the same input event"
}

variable "dd_api_url" {
  type        = string
  default     = null
  description = "The endpoint URL to forward the metrics to, useful for forwarding metrics through a proxy"
}

variable "dd_trace_intake_url" {
  type        = string
  default     = null
  description = "The endpoint URL to forward the traces to, useful for forwarding traces through a proxy"
}

# S3 bucket configuration
variable "dd_forwarder_bucket_name" {
  type        = string
  default     = null
  description = "The name of the forwarder bucket to create. If not provided, AWS will generate a unique name."
}

variable "dd_forwarder_buckets_access_logs_target" {
  type        = string
  default     = null
  description = "(Optional) The name of the S3 bucket to store access logs. Leave empty if access logging is not needed."
}

variable "dd_store_failed_events" {
  type        = bool
  default     = null
  description = "Set to true to enable the forwarder to store events that failed to send to Datadog."
}

variable "dd_schedule_retry_failed_events" {
  type        = bool
  default     = null
  description = "Set to true to enable a scheduled forwarder invocation (via AWS EventBridge) to process stored failed events."
}

variable "dd_schedule_retry_interval" {
  type        = number
  default     = 6
  description = "Interval in hours for scheduled forwarder invocation (via AWS EventBridge)."
}

variable "dd_forwarder_existing_bucket_name" {
  type        = string
  default     = null
  description = "The name of an existing s3 bucket to use. If not provided, a new bucket will be created."
}

variable "dd_log_level" {
  type        = string
  default     = null
  nullable    = true
  description = "Set the log level for the forwarder. Valid values are DEBUG, INFO, WARN, ERROR, CRITICAL. If not set, default is WARN."

  validation {
    condition     = var.dd_log_level == null ? true : contains(["DEBUG", "INFO", "WARN", "ERROR", "CRITICAL"], var.dd_log_level)
    error_message = "dd_log_level must be one of: DEBUG, INFO, WARN, ERROR, CRITICAL."
  }
}

variable "dd_trace_enabled" {
  type        = bool
  default     = true
  description = "Set to false to disable trace forwarding."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to all AWS resources created by this module that support tagging."
}

variable "region" {
  type        = string
  description = "AWS region to deploy the Datadog Forwarder to. If empty, the forwarder will be deployed to the region set by the provider."
  default     = null
}
