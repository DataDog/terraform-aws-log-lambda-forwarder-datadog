# VPC Datadog Forwarder Example

This example demonstrates deploying the Datadog Forwarder in a VPC, either using an existing VPC or creating a new one.

## Features

- **VPC Deployment**: Lambda function deployed within a VPC
- **Network Security**: Controlled egress through security groups
- **NAT Gateway**: Internet access for Lambda function (if creating new VPC)
- **Proxy Support**: Optional HTTP proxy configuration
- **Failed Events Storage**: S3 bucket for failed events and caching

## Architecture

When `create_vpc = true`, this creates:
- VPC with public and private subnets across 2 AZs
- Internet Gateway for public subnets
- NAT Gateways for private subnet internet access
- Security Group allowing HTTPS and DNS egress
- Lambda function in private subnets

## Usage

1. Set your variables:
   ```bash
   export TF_VAR_datadog_api_key="your-datadog-api-key"
   ```

2. Optionally edit `main.tf` if you wish to use an existing VPC
   and security group.

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```


## Network Requirements

For the forwarder to work in a VPC, it needs:

### Internet Access
- Direct internet access via Internet Gateway + NAT Gateway, OR
- HTTP proxy server, OR
- VPC Endpoints for AWS services + proxy/VPC endpoints for Datadog

### Required Egress Rules
```hcl
# HTTPS to Datadog
egress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# DNS resolution
egress {
  from_port   = 53
  to_port     = 53
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

## Proxy Configuration

To use an HTTP proxy:

```bash
terraform apply \
  -var="proxy_url=http://my-proxy.example.com:8080" \
  -var="no_proxy=169.254.169.254,s3.amazonaws.com"
```

This configures:
- `HTTP_PROXY` and `HTTPS_PROXY` environment variables
- `NO_PROXY` for AWS metadata and services
- SSL validation disabled (required for many proxies)

## Use Cases

### High Security Environments
- Controlled network egress
- Inspection of all outbound traffic
- Integration with corporate proxy infrastructure

### Compliance Requirements
- Network isolation requirements
- Audit trail of network connections
- Integration with existing VPC infrastructure

### Multi-Account Architectures
- Shared VPC across multiple accounts
- Centralized network security policies
- Integration with Transit Gateway

## Clean up

```bash
terraform destroy
```

Note: Destroying will remove NAT Gateways and release Elastic IPs.
