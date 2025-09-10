terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}


# (Optional) Create VPC using terraform-aws-vpc module
# This is an example to demonstrate a working configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.function_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  private_subnet_tags = {
    Type = "private"
  }

  public_subnet_tags = {
    Type = "public"
  }

  tags = {
    Environment = "example"
  }
}

# (Optional) Create security group for Lambda function
# This is an example to demonstrate a working configuration
resource "aws_security_group" "forwarder" {
  name_prefix = "${var.function_name}-"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "HTTPS to Datadog"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.function_name}-sg"
  }
}

module "datadog_forwarder" {
  source = "../../"

  # API key configuration
  dd_api_key = var.datadog_api_key
  dd_site    = var.datadog_site

  # Lambda configuration
  function_name = var.function_name
  memory_size   = var.memory_size
  timeout       = var.timeout

  # VPC configuration
  dd_use_vpc             = true
  vpc_security_group_ids = [aws_security_group.forwarder.id] # edit this if you wish to use an existing security group
  vpc_subnet_ids         = module.vpc.private_subnets        # edit this if you wish to use an existing VPC

  # Proxy configuration (if using proxy)
  dd_http_proxy_url      = var.proxy_url
  dd_skip_ssl_validation = var.proxy_url != "" ? true : false
  dd_no_proxy            = var.no_proxy

  # Datadog configuration
  dd_tags = var.dd_tags

  # S3 configuration for caching
  dd_store_failed_events = true
}

# Example CloudWatch Log Group to forward
resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/test-log-group-vpc"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_stream" "example" {
  name           = "test"
  log_group_name = aws_cloudwatch_log_group.example.name
}

# Log subscription filter to forward logs to Datadog
resource "aws_cloudwatch_log_subscription_filter" "datadog_log_filter" {
  name            = "datadog-log-filter"
  log_group_name  = aws_cloudwatch_log_group.example.name
  filter_pattern  = ""
  destination_arn = module.datadog_forwarder.datadog_forwarder_arn
}
