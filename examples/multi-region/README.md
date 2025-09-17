# Multi-Region Datadog Forwarder Example

This example demonstrates a basic forwarder setup deployed across 2 regions.

## Features

- Creates Datadog forwarders in 2 regions with minimal configuration
- API key stored in AWS Secrets Manager automatically
- Uses all default settings for simplicity

**Alternative API Key Configuration**: Instead of providing the API key directly, you can:
- Supply the ARN of an existing AWS Secrets Manager secret containing your Datadog API key by using `dd_api_key_secret_arn` instead of `dd_api_key`
- Supply the name of an existing SSM Parameter containing your Datadog API key by using `dd_api_key_ssm_parameter_name` instead of `dd_api_key`

## Usage

1. Set your variables:
   ```bash
   export TF_VAR_datadog_api_key="your-datadog-api-key"
   ```

2. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## What gets created

- **Datadog Forwarder Lambdas**: One in each configured region with default settings
- **Secrets Manager Secrets**: Automatically created in each region to store your API key
- **IAM Roles**: With necessary permissions for basic log forwarding in each region

## Clean up

```bash
terraform destroy
```
