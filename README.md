# Datadog Log Lambda Forwarder for AWS

This Terraform module creates the Datadog Log Lambda Forwarder infrastructure in AWS, which pushes logs, metrics, and traces from AWS services to Datadog.

## Features

- **Lambda Function**: Main forwarder function that processes and forwards AWS observability data to Datadog
- **IAM Role**: Execution role with appropriate permissions for S3, KMS, Secrets Manager, and other AWS services
- **S3 Bucket**: Storage for failed events and caching, with encryption and lifecycle policies
- **Lambda Permissions**: For invocation by CloudWatch Logs, S3, SNS, and EventBridge
- **Secrets Management**: Support for storing Datadog API key in Secrets Manager or SSM Parameter Store
- **VPC Support**: Deploy forwarder in VPC with proxy

## Usage

For complete usage examples demonstrating different configuration scenarios, see the [examples](./examples/) directory:

- **[Basic Example](./examples/basic/)** - Simple setup with minimal configuration, includes examples for API key storage using Secrets Manager or SSM Parameter Store
- **[VPC Example](./examples/vpc/)** - VPC deployment with enhanced metrics, custom log processing, and comprehensive tagging

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

### Required

| Name | Description | Type | Default |
|------|-------------|------|---------|
| dd_site | Datadog site to send data to. Options: `datadoghq.com`, `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com`, `ap1.datadoghq.com`, `ap2.datadoghq.com`, `ddog-gov.com` | `string` | `"datadoghq.com"` |

**Note**: You must provide **one** of the following for the Datadog API key:
- `dd_api_key` - The API key directly (will be stored in Secrets Manager)
- `dd_api_key_secret_arn` - ARN of existing Secrets Manager secret containing the API key
- `dd_api_key_ssm_parameter_name` - Name of SSM Parameter containing the API key

### Lambda Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| function_name | Lambda function name | `string` | `"DatadogForwarder"` |
| memory_size | Memory size (128-3008 MB) | `number` | `1024` |
| timeout | Timeout in seconds | `number` | `120` |
| reserved_concurrency | Reserved concurrency (empty for unreserved) | `string` | `""` |
| log_retention_in_days | CloudWatch log retention | `number` | `90` |
| source_code_version | Forwarder source code version | `string` | `"4.12.0"` |
| layer_version | Version of the Datadog Forwarder Lambda layer | `string` | `"87"` |
| install_as_layer | Use Lambda layer (recommended) | `bool` | `true` |
| layer_arn | Custom layer ARN (optional) | `string` | `""` |

### Datadog Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| dd_tags | Custom tags for forwarded logs | `string` | `""` |
| dd_fetch_lambda_tags | Fetch Lambda tags | `bool` | `true` |
| dd_fetch_log_group_tags | Fetch Log Group tags | `bool` | `false` |
| dd_fetch_step_functions_tags | Fetch Step Functions tags | `bool` | `false` |
| dd_fetch_s3_tags | Fetch S3 bucket tags | `bool` | `false` |
| dd_trace_enabled | Enable trace forwarding | `bool` | `true` |
| dd_enhanced_metrics | Enable enhanced Lambda metrics | `bool` | `false` |

### Log Processing

| Name | Description | Type | Default |
|------|-------------|------|---------|
| redact_ip | Redact IP addresses | `bool` | `false` |
| redact_email | Redact email addresses | `bool` | `false` |
| dd_scrubbing_rule | Regex pattern for log scrubbing | `string` | `""` |
| dd_scrubbing_rule_replacement | Replacement text for scrubbing | `string` | `""` |
| exclude_at_match | Regex to exclude logs | `string` | `""` |
| include_at_match | Regex to include only matching logs | `string` | `""` |
| dd_multiline_log_regex_pattern | Regex for multiline log detection | `string` | `""` |
| dd_forward_log | Enable log forwarding | `bool` | `true` |
| dd_step_functions_trace_enabled | Enable Step Functions tracing | `bool` | `false` |

### Network Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| dd_use_vpc | Deploy in VPC | `bool` | `false` |
| vpc_security_group_ids | VPC Security Group IDs | `list(string)` | `[]` |
| vpc_subnet_ids | VPC Subnet IDs | `list(string)` | `[]` |
| dd_http_proxy_url | HTTP proxy URL | `string` | `""` |
| dd_no_proxy | NO_PROXY environment variable | `string` | `""` |
| dd_no_ssl | Disable SSL | `bool` | `false` |
| dd_url | Custom endpoint URL | `string` | `""` |
| dd_port | Custom endpoint port | `string` | `""` |
| dd_skip_ssl_validation | Skip SSL validation | `bool` | `false` |
| dd_use_compression | Enable log compression | `bool` | `true` |
| dd_compression_level | Compression level (0-9) | `number` | `6` |
| dd_max_workers | Max concurrent workers | `number` | `20` |

### S3 Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| dd_forwarder_bucket_name | S3 bucket name to create | `string` | `""` |
| dd_forwarder_existing_bucket_name | Existing S3 bucket name to use | `string` | `""` |
| dd_store_failed_events | Store failed events in S3 | `bool` | `false` |
| dd_forwarder_buckets_access_logs_target | Access logs target bucket | `string` | `""` |

### IAM Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| iam_role_path | IAM role path | `string` | `"/"` |
| permissions_boundary_arn | Permissions boundary ARN | `string` | `""` |

### Advanced Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| tags_cache_ttl_seconds | Tags cache TTL in seconds | `number` | `300` |
| additional_target_lambda_arns | Additional Lambda ARNs to invoke | `list(string)` | `[]` |
| dd_api_url | Custom API endpoint URL | `string` | `""` |
| dd_trace_intake_url | Custom trace intake URL | `string` | `""` |
| dd_log_level | Log level (DEBUG, INFO, WARN, ERROR, CRITICAL) | `string` | `"WARN"` |
| tags | Map of tags to assign to all AWS resources created by this module | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| datadog_forwarder_arn | Datadog Forwarder Lambda Function ARN |
| datadog_forwarder_function_name | Datadog Forwarder Lambda Function Name |
| datadog_forwarder_role_arn | Forwarder IAM Role ARN |
| datadog_forwarder_role_name | Forwarder IAM Role Name |
| dd_api_key_secret_arn | Secrets Manager secret ARN (if created) |
| forwarder_bucket_name | S3 bucket name (if created or existing) |
| forwarder_bucket_arn | S3 bucket ARN (if created) |
| forwarder_log_group_name | CloudWatch Log Group name |
| forwarder_log_group_arn | CloudWatch Log Group ARN |

## Setting up Log Forwarding

After deploying the forwarder, you need to configure your AWS services to send telemetry data to it.

### Recommended: Automatic Trigger Setup

The easiest way to set up log forwarding is using Datadog's automatic trigger configuration, configured on your AWS Account Integration in Datadog. Datadog automatically retrieves the log locations for the selected AWS services and adds them as triggers on the Datadog Forwarder Lambda function. Datadog also keeps the list up to date.

**[Datadog's Automatic Trigger Setup Guide](https://docs.datadoghq.com/logs/guide/send-aws-services-logs-with-the-datadog-lambda-function/?tab=awsconsole#automatically-set-up-triggers)**

This method automatically configures triggers for services like CloudWatch Log Groups, S3 buckets, and other AWS services without requiring manual Terraform configuration.

### Manual Trigger Setup

The [examples](./examples/) directory contains practical implementations of log subscription filters and event triggers. Common integration patterns include:

- **CloudWatch Log Groups**: Subscription filters to forward log streams
- **S3 Bucket Notifications**: Trigger forwarder when log files are uploaded
- **SNS Topics**: Forward CloudWatch alarms and other notifications
- **EventBridge Rules**: Forward custom application events

See the [basic](./examples/basic/) and [vpc](./examples/vpc/) examples for complete implementation details.

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

## Migration from CloudFormation

If you're migrating from the CloudFormation template:

1. Note your current CloudFormation stack parameters
2. Map CloudFormation parameters to Terraform variables (see parameter mapping below)
3. Import existing resources if needed using `terraform import`

### Parameter Mapping

| CloudFormation Parameter | Terraform Variable |
|--------------------------|-------------------|
| `DdApiKey` | `dd_api_key` |
| `DdApiKeySecretArn` | `dd_api_key_secret_arn` |
| `DdApiKeySsmParameterName` | `dd_api_key_ssm_parameter_name` |
| `DdSite` | `dd_site` |
| `FunctionName` | `function_name` |
| `MemorySize` | `memory_size` |
| `Timeout` | `timeout` |
| `ReservedConcurrency` | `reserved_concurrency` |
| `InstallAsLayer` | `install_as_layer` |
| `LayerARN` | `layer_arn` |
| `DdTags` | `dd_tags` |
| `VPCSecurityGroupIds` | `vpc_security_group_ids` |
| `VPCSubnetIds` | `vpc_subnet_ids` |

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**: Ensure the Lambda has the required IAM permissions for your log sources
2. **VPC Connectivity**: When using VPC, ensure subnets have internet access or VPC endpoints configured
3. **Layer Not Found**: Verify the layer is available in your AWS region, or provide a custom `layer_arn`
4. **API Key Issues**: Ensure the API key is valid and is associated with an org within the site specified by dd_site

### Debug Mode

Enable debug logging by setting `dd_log_level = "DEBUG"` in your module configuration.

### Monitoring

Monitor the forwarder using:
- CloudWatch Logs: `/aws/lambda/{function_name}`
- CloudWatch Metrics: Lambda function metrics
- Datadog: Enhanced metrics (if enabled)

## License

This module is licensed under the Apache 2.0 License.

## References

- [Datadog Log Collection Documentation](https://docs.datadoghq.com/logs/log_collection/aws/)
- [Datadog Forwarder GitHub Repository](https://github.com/DataDog/datadog-serverless-functions/tree/master/aws/logs_monitoring)
