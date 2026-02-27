# Dev Guide

## Prerequisites

- Terraform 1.9.x (`tfenv` recommended — see note on version compatibility below)
- AWS credentials required for `command = apply` tests and live examples
- Plan-only tests in `create_api_key_secret_flag.tftest.hcl` use `mock_provider` and run without credentials

```bash
brew install tfenv && tfenv install 1.9.8 && tfenv use 1.9.8
```

> **Terraform version compatibility:** The module requires `>= 1.9` (native test framework).
> Terraform 1.12 introduced stricter sensitive-output validation that the current `outputs.tf`
> doesn't satisfy — use 1.9.x for local testing until that is addressed.

> **`OTEL_TRACES_EXPORTER` note:** If you see `Could not initialize telemetry` errors, run
> `unset OTEL_TRACES_EXPORTER` before running Terraform commands.

---

## Running tests

All tests live in `tests/` and use [Terraform's native test framework](https://developer.hashicorp.com/terraform/language/tests).

```bash
# Run all tests
TFENV_TERRAFORM_VERSION=1.9.8 terraform test

# Run a single test file
TFENV_TERRAFORM_VERSION=1.9.8 terraform test -filter=tests/<file>.tftest.hcl
```

> **Credentials:** Most tests require AWS credentials because the AWS provider validates
> credentials during initialization, even for `command = plan`. The exception is
> `create_api_key_secret_flag.tftest.hcl`, which uses `mock_provider "aws"`.

---

## Test files

| File | Mode | Credentials needed | What it tests |
|---|---|---|---|
| `create_api_key_secret_flag.tftest.hcl` | plan | **No** (mock_provider) | `create_dd_api_key_secret` flag — all variable scenarios and validation rules |
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

## Live examples

`examples/` contains deployable root modules for manual end-to-end testing:

```bash
cd examples/<name>
export TF_VAR_datadog_api_key="your-api-key"
terraform init && terraform plan
terraform apply   # optional — creates real AWS resources
terraform destroy
```

| Directory | What it demonstrates |
|---|---|
| `basic/` | Minimal setup — API key via `dd_api_key` |
| `vpc/` | VPC deployment |
| `multi-region/` | Multi-region deployment |
| `external-secret/` | Secret created in the same plan, ARN passed to module |

---

## Adding new tests

1. Create `tests/<scenario>.tftest.hcl`
2. Use `command = plan` with `mock_provider "aws"` to run without credentials (see template below)
3. Always set `region = "us-east-1"` in the top-level `variables {}` block when using `mock_provider` — this bypasses `data.aws_region.current` which otherwise returns a random mock string
4. Use `override_data` to mock the GitHub releases HTTP call in each `run` block — values must be raw JSON strings (`jsonencode()` is not allowed in `override_data`)
5. Use `expect_failures = [var.foo]` to assert that validation rules reject bad input
6. Use `command = apply` only when asserting on computed values (e.g. env var values referencing created resource IDs) — requires real AWS credentials

### Credential-free test template

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
