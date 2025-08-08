# Basic Datadog Forwarder Example

This example demonstrates the most basic usage of the Datadog Forwarder module.

## Features

- Creates a Datadog forwarder with minimal configuration
- API key stored in AWS Secrets Manager automatically
- Includes an example CloudWatch Log Group with subscription filter
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

- **Datadog Forwarder Lambda**: With default settings (1024MB memory, 120s timeout)
- **Secrets Manager Secret**: Automatically created to store your API key
- **IAM Role**: With necessary permissions for basic log forwarding
- **CloudWatch Log Group**: Example log group (`/aws/lambda/example-function`)
- **Log Subscription Filter**: Forwards logs from the example log group to Datadog

## Clean up

```bash
terraform destroy
```
