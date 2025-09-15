# Terraform Tests

This directory contains Terraform tests for the Datadog Log Lambda Forwarder module using the official Terraform testing framework.

## Test Files

### `default_config.tftest.hcl`
Tests the default base configuration of the module with minimal required parameters:
- Lambda function with default settings (1024MB memory, 120s timeout, layer-based deployment)
- IAM role creation
- Secrets Manager secret creation
- CloudWatch Log Group configuration
- Lambda permissions
- Environment variable defaults

### `vpc_config.tftest.hcl`
Tests VPC-specific configuration:
- VPC Lambda deployment
- Security group and subnet configuration
- Proxy environment variables
- S3 bucket creation for caching

### `existing_resources.tftest.hcl`
Tests using existing AWS resources instead of creating new ones:
- Existing IAM role usage
- Existing S3 bucket usage
- Existing Secrets Manager secret usage
- Resource reference validation

### `enhanced_features.tftest.hcl`
Tests advanced features and non-default configurations:
- Enhanced Lambda metrics
- Tag fetching capabilities
- Failed event storage
- Custom Lambda settings (memory, timeout)
- Non-layer deployment method

## Running Tests

### Prerequisites
- Terraform >= 1.6 (required for `terraform test` command)
- AWS credentials configured
- Datadog API key (can be a test value for plan-only tests)

### Execute All Tests
```bash
terraform test
```

### Execute Specific Test File
```bash
terraform test -filter=tests/default_config.tftest.hcl
```

### Test with Variables
```bash
# Set environment variables
export TF_VAR_dd_api_key="your-test-api-key"

# Or create terraform.tfvars in the root directory
echo 'dd_api_key = "your-test-api-key"' > terraform.tfvars

terraform test
```

## Test Strategy

These tests use the `command = plan` strategy, which means they:
- ✅ Validate Terraform configuration syntax
- ✅ Check resource configuration and attributes
- ✅ Verify conditional logic and resource creation
- ✅ Test input validation and defaults
- ❌ Do not create actual AWS resources
- ❌ Do not test runtime behavior

For integration testing with actual AWS resources, consider:
- Running `terraform apply` in the examples directory
- Using tools like Terratest for Go-based testing
- Implementing CI/CD pipelines with temporary AWS environments

## Continuous Integration

To run these tests in CI/CD:

```yaml
# Example GitHub Actions workflow
- name: Terraform Test
  run: |
    export TF_VAR_dd_api_key="${{ secrets.DATADOG_API_KEY }}"
    terraform test
```

## Adding New Tests

When adding new test cases:
1. Create a new `.tftest.hcl` file in the `tests/` directory
2. Use descriptive test names and error messages
3. Test both positive and negative scenarios
4. Include assertions for critical resource attributes
5. Update this README with test descriptions