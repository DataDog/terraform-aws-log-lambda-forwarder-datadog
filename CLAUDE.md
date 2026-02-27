# Dev Guide

## Prerequisites

- Terraform 1.9.x (uses native `terraform test` — avoid 1.10+ due to `lifecycle`-in-module restriction)
- `tfenv` recommended: `brew install tfenv && tfenv install 1.9.8 && tfenv use 1.9.8`
- AWS credentials required for `command = apply` tests and live examples
- Plan-only tests in `create_api_key_secret_flag.tftest.hcl` use `mock_provider` and run without credentials

> **Note on `OTEL_TRACES_EXPORTER`:** If you see `Could not initialize telemetry` errors, unset
> the variable: `unset OTEL_TRACES_EXPORTER`

---

## Running tests

All tests live in `tests/` and use [Terraform's native test framework](https://developer.hashicorp.com/terraform/language/tests).

```bash
# Run all tests (mix of plan-only and apply tests)
TFENV_TERRAFORM_VERSION=1.9.8 terraform test

# Fast path: credential-free unit tests for the issue #8 fix (mock_provider)
TFENV_TERRAFORM_VERSION=1.9.8 terraform test -filter=tests/create_api_key_secret_flag.tftest.hcl

# Single test file
TFENV_TERRAFORM_VERSION=1.9.8 terraform test -filter=tests/default_config.tftest.hcl
```

> **Note:** Most tests require AWS credentials because the AWS provider validates credentials
> during initialization — even for `command = plan`. The exception is
> `create_api_key_secret_flag.tftest.hcl`, which uses `mock_provider "aws"`.

---

## Test files and what they cover

| File | Mode | Credentials needed | What it tests |
|---|---|---|---|
| `create_api_key_secret_flag.tftest.hcl` | plan | **No** (mock_provider) | **`create_dd_api_key_secret` flag** — all scenarios for issue #8 fix |
| `default_config.tftest.hcl` | plan + apply | Yes | Default variable values, Lambda config, IAM, CloudWatch |
| `existing_resources.tftest.hcl` | plan | Yes | Using pre-existing IAM role, S3 bucket, and secret ARN |
| `enhanced_features.tftest.hcl` | plan + apply | Yes | Tag fetching, S3 bucket creation, layer version pinning |
| `optional_env_vars.tftest.hcl` | apply | Yes | Every optional env var is correctly set / omitted |
| `vpc_config.tftest.hcl` | plan | Yes | VPC deployment configuration |
| `multi_region.tftest.hcl` | plan | Yes | Multi-region deployment |
| `enrich_fetch_variables.tftest.hcl` | plan | Yes | Enrich vs fetch tag variable mutual exclusion |
| `character_limit.tftest.hcl` | plan | Yes | Variable length/character validation |
| `forwarder_version_tag.tftest.hcl` | plan + apply | Yes | Version tagging on created resources |

---

## Testing the issue #8 fix (Invalid count argument)

The bug manifests when `dd_api_key_secret_arn` is set to an ARN that comes from a resource
created in the **same Terraform plan** — the value is unknown at plan time, causing:

```
Error: Invalid count argument
The "count" value depends on resource attributes that cannot be determined until apply
```

### Fast path: unit tests (no AWS needed)

```bash
unset OTEL_TRACES_EXPORTER
TFENV_TERRAFORM_VERSION=1.9.8 terraform test -filter=tests/create_api_key_secret_flag.tftest.hcl
```

This runs 9 plan-only tests (all pass without real credentials) covering:
- `create_dd_api_key_secret = false` with `dd_api_key_secret_arn`
- `create_dd_api_key_secret = false` with `dd_api_key_ssm_parameter_name`
- `create_dd_api_key_secret = true` explicit
- Automatic detection (null flag) — backward compatibility
- Validation failures for invalid configurations

### Full reproduction: live example (AWS credentials required)

`examples/external-secret/` is a minimal root module that reproduces the exact bug scenario:
it creates an `aws_secretsmanager_secret` and passes its ARN to the forwarder module in the
same plan, which is what triggered the original error.

```bash
cd examples/external-secret

export TF_VAR_datadog_api_key="your-api-key"

# This should succeed on the fixed branch, and fail with "Invalid count argument"
# if you revert the create_dd_api_key_secret changes to main.tf / data.tf
terraform init
terraform plan

# Optional: actually deploy
terraform apply
terraform destroy
```

### Manually reproducing the original bug

To confirm the fix is necessary, revert `local.should_create_secret` in `data.tf` to the
original expression and re-run `terraform plan` in `examples/external-secret/`:

```hcl
# data.tf — original (broken) expression:
should_create_secret = var.dd_api_key_secret_arn == null && var.dd_api_key_ssm_parameter_name == null
```

`terraform plan` will immediately fail with the "Invalid count argument" error.

---

## Adding new tests

1. Create `tests/<scenario>.tftest.hcl`
2. Use `command = plan` with `mock_provider "aws"` to run without credentials (see `create_api_key_secret_flag.tftest.hcl` as a template)
3. Always set `region = "us-east-1"` in the top-level `variables {}` block when using mocks — this bypasses `data.aws_region.current` which returns a random string from the mock provider
4. Use `override_data { target = data.http.github_releases; values = { response_body = "..." } }` in each `run` block to mock the GitHub releases API call (must be a raw JSON string — `jsonencode()` is not allowed in `override_data` values)
5. Use `expect_failures = [var.foo]` to assert that validation rules reject bad input
6. Use `command = apply` only when you need to assert on computed values (e.g. env var values that reference created resource IDs) — these require real AWS credentials

### Minimal credential-free template

```hcl
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
}

variables {
  dd_site = "datadoghq.com"
  region  = "us-east-1"  # required when using mock_provider
}

run "my_scenario" {
  command = plan

  variables {
    dd_api_key = "test-api-key-value"
  }

  override_data {
    target = data.http.github_releases
    values = {
      response_body = "[{\"name\":\"aws-dd-forwarder-5.1.0 (Layer v92)\",\"tag_name\":\"aws-dd-forwarder-5.1.0\"}]"
    }
  }

  assert {
    condition     = length(aws_secretsmanager_secret.dd_api_key_secret) == 1
    error_message = "Expected secret to be created"
  }
}
```
