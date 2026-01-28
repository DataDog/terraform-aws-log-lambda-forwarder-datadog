# Datadog Log Lambda Forwarder for AWS

This Terraform module creates the Datadog Log Lambda Forwarder infrastructure in AWS, which pushes logs, metrics, and traces from AWS services to Datadog.

## Features

- **Lambda Function**: Main forwarder function that processes and forwards AWS observability data to Datadog
- **IAM Role**: Execution role with appropriate permissions for S3, KMS, Secrets Manager, and other AWS services
- **S3 Bucket**: Storage for failed events and caching, with encryption and lifecycle policies
- **Lambda Permissions**: For invocation by CloudWatch Logs, S3, SNS, and EventBridge
- **Secrets Management**: Support for storing Datadog API key in Secrets Manager or SSM Parameter Store
- **VPC Support**: Deploy forwarder in VPC with proxy
- **Scheduler**: For scheduled retry of stored failed events

## Usage

For complete usage examples demonstrating different configuration scenarios, see the [examples](https://github.com/DataDog/terraform-aws-log-lambda-forwarder-datadog/tree/main/examples) directory:

- **[Basic Example](https://github.com/DataDog/terraform-aws-log-lambda-forwarder-datadog/tree/main/examples/basic)** - Simple setup with minimal configuration, includes examples for API key storage using Secrets Manager or SSM Parameter Store
- **[VPC Example](https://github.com/DataDog/terraform-aws-log-lambda-forwarder-datadog/tree/main/examples/vpc)** - VPC deployment with enhanced metrics, custom log processing, and comprehensive tagging
- **[Multi-Region Example](https://github.com/DataDog/terraform-aws-log-lambda-forwarder-datadog/tree/main/examples/multi-region)** - Basic forwarder setup deployed across multiple AWS regions

## Requirements

| Name      | Version |
| --------- | ------- |
| terraform | >= 1.9  |
| aws       | >= 6.0  |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | >= 5.0  |

## Inputs

### Required

| Name    | Description                                                                                                                                                                | Type     | Default           |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------- |
| dd_site | Datadog site to send data to. Options: `datadoghq.com`, `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com`, `ap1.datadoghq.com`, `ap2.datadoghq.com`, `ddog-gov.com` | `string` | `"datadoghq.com"` |

**Note**: You must provide **one** of the following for the Datadog API key:

- `dd_api_key` - The API key directly (will be stored in Secrets Manager)
- `dd_api_key_secret_arn` - ARN of existing Secrets Manager secret containing the API key
- `dd_api_key_ssm_parameter_name` - Name of SSM Parameter containing the API key

### AWS Configuration

| Name   | Description                                                                                                                | Type     | Default |
| ------ | -------------------------------------------------------------------------------------------------------------------------- | -------- | ------- |
| region | AWS region to deploy the Datadog Forwarder to. If empty, the forwarder will be deployed to the region set by the provider. | `string` | `null`  |

### Lambda Configuration

| Name                  | Description                                                                                                                                                                       | Type          | Default              |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | -------------------- |
| function_name         | Lambda function name                                                                                                                                                              | `string`      | `"DatadogForwarder"` |
| memory_size           | Memory size (128-3008 MB)                                                                                                                                                         | `number`      | `1024`               |
| timeout               | Timeout in seconds                                                                                                                                                                | `number`      | `120`                |
| reserved_concurrency  | Reserved concurrency                                                                                                                                                              | `string`      | `null`               |
| log_retention_in_days | CloudWatch log retention                                                                                                                                                          | `number`      | `90`                 |
| layer_version         | Version of the Datadog Forwarder Lambda layer                                                                                                                                     | `string`      | `"latest"`           |
| layer_arn             | Custom layer ARN (optional)                                                                                                                                                       | `string`      | `null`               |
| existing_iam_role_arn | ARN of existing IAM role. **Requires** `dd_forwarder_existing_bucket_name` and either `dd_api_key_secret_arn` or `dd_api_key_ssm_parameter_name` to avoid cross-region conflicts. | `string`      | `null`               |
| tags                  | Resource tags                                                                                                                                                                     | `map(string)` | `{}`                 |

### Datadog Configuration

| Name                          | Description                      | Type     | Default           |
| ----------------------------- | -------------------------------- | -------- | ----------------- |
| dd_api_key                    | Datadog API key                  | `string` | `null`            |
| dd_api_key_secret_arn         | ARN of secret storing API key    | `string` | `null`            |
| dd_api_key_ssm_parameter_name | SSM parameter name for API key   | `string` | `null`            |
| dd_site                       | Datadog site                     | `string` | `"datadoghq.com"` |
| dd_tags                       | Custom tags for forwarded logs   | `string` | `null`            |
| dd_source                     | Custom source for forwarded logs | `string` | `null`            |
| dd_trace_enabled              | Enable trace forwarding          | `bool`   | `true`            |
| dd_enhanced_metrics           | Enable enhanced Lambda metrics   | `bool`   | `false`           |

### Tag Enrichment & Fetching

| Name                         | Description                                                                                                                                                   | Type   | Default |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------- |
| dd_enrich_s3_tags            | Enrich logs from S3 with bucket tags via Datadog backend (requires Resource Collection enabled). Mutually exclusive with `dd_fetch_s3_tags`                   | `bool` | `null`  |
| dd_enrich_cloudwatch_tags    | Enrich logs from CloudWatch with log group tags via Datadog backend (requires Resource Collection enabled). Mutually exclusive with `dd_fetch_log_group_tags` | `bool` | `null`  |
| dd_fetch_lambda_tags         | Fetch Lambda tags                                                                                                                                             | `bool` | `null`  |
| dd_fetch_log_group_tags      | **(Deprecated in favor of dd_enrich_cloudwatch_tags)** Fetch Log Group tags                                                                                   | `bool` | `null`  |
| dd_fetch_step_functions_tags | Fetch Step Functions tags                                                                                                                                     | `bool` | `null`  |
| dd_fetch_s3_tags             | **(Deprecated in favor of dd_enrich_s3_tags)** Fetch S3 bucket tags                                                                                           | `bool` | `null`  |

### Log Processing

| Name                            | Description                         | Type     | Default |
| ------------------------------- | ----------------------------------- | -------- | ------- |
| dd_forward_log                  | Enable log forwarding               | `bool`   | `null`  |
| dd_step_functions_trace_enabled | Enable Step Functions tracing       | `bool`   | `null`  |
| dd_use_compression              | Enable log compression              | `bool`   | `null`  |
| redact_ip                       | Redact IP addresses                 | `bool`   | `null`  |
| redact_email                    | Redact email addresses              | `bool`   | `null`  |
| dd_scrubbing_rule               | Regex pattern for log scrubbing     | `string` | `null`  |
| dd_scrubbing_rule_replacement   | Replacement text for scrubbing      | `string` | `null`  |
| exclude_at_match                | Regex to exclude logs               | `string` | `null`  |
| include_at_match                | Regex to include only matching logs | `string` | `null`  |
| dd_multiline_log_regex_pattern  | Regex for multiline log detection   | `string` | `null`  |

### Network Configuration

| Name                   | Description                                                     | Type           | Default |
| ---------------------- | --------------------------------------------------------------- | -------------- | ------- |
| dd_use_vpc             | Deploy in VPC                                                   | `bool`         | `false` |
| vpc_security_group_ids | VPC Security Group IDs                                          | `list(string)` | `[]`    |
| vpc_subnet_ids         | VPC Subnet IDs                                                  | `list(string)` | `[]`    |
| dd_http_proxy_url      | List of url endpoints your proxy server exposes                 | `string`       | `null`  |
| dd_no_proxy            | List of domain names that should be excluded from the web proxy | `string`       | `null`  |
| dd_no_ssl              | Disable SSL                                                     | `string`       | `null`  |
| dd_url                 | Custom endpoint URL                                             | `string`       | `null`  |
| dd_port                | Custom endpoint port                                            | `string`       | `null`  |
| dd_skip_ssl_validation | Skip SSL validation                                             | `bool`         | `null`  |

### Advanced Configuration

| Name                              | Description                                            | Type     | Default |
| --------------------------------- | ------------------------------------------------------ | -------- | ------- |
| dd_compression_level              | Compression level (0-9)                                | `string` | `null`  |
| dd_max_workers                    | Max concurrent workers                                 | `string` | `null`  |
| dd_log_level                      | Log level                                              | `string` | `null`  |
| dd_store_failed_events            | Store failed events in S3                              | `bool`   | `null`  |
| dd_schedule_retry_failed_events   | Periodically retry failed events (via AWS EventBridge) | `bool`   | `null`  |
| dd_schedule_retry_interval        | Retry interval in hours for failed events              | `number` | `6`     |
| dd_forwarder_bucket_name          | Custom S3 bucket name                                  | `string` | `null`  |
| dd_forwarder_existing_bucket_name | Existing S3 bucket name                                | `string` | `null`  |
| dd_api_url                        | Custom API URL                                         | `string` | `null`  |
| dd_trace_intake_url               | Custom trace intake URL                                | `string` | `null`  |
| additional_target_lambda_arns     | Additional Lambda ARNs to invoke                       | `string` | `null`  |

### IAM Configuration

| Name                                    | Description                            | Type           | Default |
| --------------------------------------- | -------------------------------------- | -------------- | ------- |
| iam_role_path                           | IAM role path                          | `string`       | `"/"`   |
| permissions_boundary_arn                | Permissions boundary ARN               | `string`       | `null`  |
| tags_cache_ttl_seconds                  | Tags cache TTL in seconds              | `number`       | `300`   |
| dd_allowed_kms_keys                     | Allow access to following KMS Key ARNs | `list(string)` | `["*"]` |
| dd_forwarder_buckets_access_logs_target | Access logs target bucket              | `string`       | `null`  |

## Boolean Variable Behavior

For boolean variables with `null` defaults, three states are supported:

- `true` → Sets environment variable to `"true"`
- `false` → Sets environment variable to `"false"`
- `null` (unset) → Environment variable not set (uses forwarder defaults)

## Outputs

| Name                            | Description                             |
| ------------------------------- | --------------------------------------- |
| datadog_forwarder_arn           | Datadog Forwarder Lambda Function ARN   |
| datadog_forwarder_function_name | Datadog Forwarder Lambda Function Name  |
| datadog_forwarder_role_arn      | Forwarder IAM Role ARN                  |
| datadog_forwarder_role_name     | Forwarder IAM Role Name                 |
| dd_api_key_secret_arn           | Secrets Manager secret ARN (if created) |
| forwarder_bucket_name           | S3 bucket name (if created or existing) |
| forwarder_bucket_arn            | S3 bucket ARN (if created)              |
| forwarder_log_group_name        | CloudWatch Log Group name               |
| forwarder_log_group_arn         | CloudWatch Log Group ARN                |

## Setting up Log Forwarding

After deploying the forwarder, you need to configure your AWS services to send telemetry data to it.

### Recommended: Automatic Trigger Setup

The easiest way to set up log forwarding is using Datadog's automatic trigger configuration, configured on your AWS Account Integration in Datadog. Datadog automatically retrieves the log locations for the selected AWS services and adds them as triggers on the Datadog Forwarder Lambda function. Datadog also keeps the list up to date.

**[Datadog's Automatic Trigger Setup Guide](https://docs.datadoghq.com/logs/guide/send-aws-services-logs-with-the-datadog-lambda-function/?tab=awsconsole#automatically-set-up-triggers)**

This method automatically configures triggers for services like CloudWatch Log Groups, S3 buckets, and other AWS services without requiring manual Terraform configuration.

### Manual Trigger Setup

The [examples](https://github.com/DataDog/terraform-aws-log-lambda-forwarder-datadog/tree/main/examples) directory contains practical implementations of log subscription filters and event triggers. Common integration patterns include:

- **CloudWatch Log Groups**: Subscription filters to forward log streams
- **S3 Bucket Notifications**: Trigger forwarder when log files are uploaded
- **SNS Topics**: Forward CloudWatch alarms and other notifications
- **EventBridge Rules**: Forward custom application events

See the [basic](https://github.com/DataDog/terraform-aws-log-lambda-forwarder-datadog/tree/main/examples/basic) and [vpc](https://github.com/DataDog/terraform-aws-log-lambda-forwarder-datadog/tree/main/examples/vpc) examples for complete implementation details.

## IAM Permissions

The forwarder Lambda function is granted the following permissions:

- **S3**: Read access to all S3 objects for log processing
- **S3**: Read/write access to the forwarder bucket for caching and failed events
- **KMS**: Decrypt access for encrypted S3 buckets
- **Secrets Manager**: Read access to the Datadog API key secret
- **SSM**: Read access to SSM parameters (if using SSM for API key)
- **Resource Groups**: Read access for tag fetching (if enabled)
- **CloudWatch Logs**: Read access for log group tags (if enabled)
- **VPC**: Network interface management (if VPC is enabled)
- **Lambda**: Invoke additional target functions (if configured)

**⚠️ Important**: When using `existing_iam_role_arn`, you must also provide `dd_forwarder_existing_bucket_name` and either `dd_api_key_secret_arn` or `dd_api_key_ssm_parameter_name`. This validation prevents cross-region resource conflicts in multi-region deployments. For details on managing your IAM, S3, and Secret resources externally to the module, see [Option 2](#option-2-bring-your-own-iam-role-s3-bucket-and-secret-reference) below.

## Multi-Region Deployments

When deploying the forwarder across multiple AWS regions, you have two options:

### Option 1: Let the Module Create Resources (Recommended)

The simplest approach is to let the module create all resources in each region:

```hcl
provider "aws" {
  region = "us-east-1"
}

# us-east-1 deployment
module "datadog_forwarder_us_east_1" {
  source = "path/to/this/module"

  function_name = "DatadogForwarder"
  dd_api_key    = var.datadog_api_key
  dd_site       = "datadoghq.com"
}

# us-west-2 deployment
module "datadog_forwarder_us_west_2" {
  source = "path/to/this/module"
  region = "us-west-2"

  function_name = "DatadogForwarder"
  dd_api_key    = var.datadog_api_key
  dd_site       = "datadoghq.com"
}
```

The module automatically includes the region in IAM resource names to prevent global resource conflicts.

### Option 2: Bring Your Own IAM Role, S3 Bucket, and Secret reference

For advanced use cases where you want to manage IAM roles centrally, you must provide **all** external resources to avoid cross-region conflicts:

```hcl
provider "aws" {
  region = "us-east-1"
}

module "datadog_forwarder_us_east_1" {
  source = "path/to/this/module"

  function_name                      = "DatadogForwarder"
  existing_iam_role_arn              = "arn:aws:iam::123456789012:role/DatadogForwarderRole"
  dd_forwarder_existing_bucket_name  = "my-global-datadog-bucket"
  dd_api_key_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-abc123"
}

module "datadog_forwarder_us_west_2" {
  source = "path/to/this/module"
  region = "us-west-2"

  function_name                      = "DatadogForwarder"
  existing_iam_role_arn              = "arn:aws:iam::123456789012:role/DatadogForwarderRole"
  dd_forwarder_existing_bucket_name  = "my-global-datadog-bucket"
  dd_api_key_secret_arn              = "arn:aws:secretsmanager:us-west-2:123456789012:secret:datadog-api-key-def456"
}
```

**Requirements when using `existing_iam_role_arn`:**

- Must specify `dd_forwarder_existing_bucket_name` (S3 bucket accessible from all regions)
- Must specify either `dd_api_key_secret_arn` or `dd_api_key_ssm_parameter_name`
- Your IAM role must have appropriate permissions for resources in each target region
- Secrets/parameters containing the Datadog API key should exist in each target region

## Scheduled retry

When you enable `dd_store_failed_events`, the Lambda forwarder stores any events that couldn’t be sent to Datadog in an S3 bucket. These events can be logs, metrics, or traces. They aren’t automatically re‑processed on each Lambda invocation; instead, you must trigger a [manual Lambda run](https://docs.datadoghq.com/logs/guide/forwarder/?tab=manual) to process them again.

You can automate this re‑processing by enabling `dd_schedule_retry_failed_events` parameter, creating a scheduled Lambda invocation through [AWS EventBridge](https://docs.aws.amazon.com/lambda/latest/dg/with-eventbridge-scheduler.html). By default, the forwarder attempts re‑processing every six hours.

Keep in mind that log events can only be submitted with [timestamps up to 18 hours in the past](https://docs.datadoghq.com/logs/log_collection/?tab=host#custom-log-forwarding); older timestamps will cause the events to be discarded.

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**: Ensure the Lambda has the required IAM permissions for your log sources
2. **VPC Connectivity**: When using VPC, ensure subnets have internet access or VPC endpoints configured
3. **API Key Issues**: Ensure the API key is valid and is associated with an org within the site specified by dd_site

### Debug Mode

Enable debug logging by setting `dd_log_level = "DEBUG"` in your module configuration.

### Monitoring

Monitor the forwarder using:

- CloudWatch Logs: `/aws/lambda/{function_name}`
- CloudWatch Metrics: Lambda function metrics

## License

This module is licensed under the Apache 2.0 License.

## References

- [Datadog Log Collection Documentation](https://docs.datadoghq.com/logs/log_collection/aws/)
- [Datadog Forwarder GitHub Repository](https://github.com/DataDog/datadog-serverless-functions/tree/master/aws/logs_monitoring)
