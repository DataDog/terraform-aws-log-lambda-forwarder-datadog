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

# Data sources for existing VPC resources
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnets" "existing" {
  count = var.create_vpc ? 0 : 1

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "private"
  }
}

data "aws_security_group" "existing" {
  count  = var.create_vpc ? 0 : 1
  vpc_id = var.vpc_id
  name   = var.security_group_name
}

# Create VPC resources if needed
resource "aws_vpc" "forwarder" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.function_name}-vpc"
  }
}

resource "aws_internet_gateway" "forwarder" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.forwarder[0].id

  tags = {
    Name = "${var.function_name}-igw"
  }
}

resource "aws_subnet" "private" {
  count = var.create_vpc ? 2 : 0

  vpc_id            = aws_vpc.forwarder[0].id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.function_name}-private-${count.index + 1}"
    Type = "private"
  }
}

resource "aws_subnet" "public" {
  count = var.create_vpc ? 2 : 0

  vpc_id                  = aws_vpc.forwarder[0].id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.function_name}-public-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_eip" "nat" {
  count = var.create_vpc ? 2 : 0

  domain = "vpc"

  tags = {
    Name = "${var.function_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.forwarder]
}

resource "aws_nat_gateway" "forwarder" {
  count = var.create_vpc ? 2 : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.function_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.forwarder]
}

resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.forwarder[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.forwarder[0].id
  }

  tags = {
    Name = "${var.function_name}-public"
  }
}

resource "aws_route_table" "private" {
  count = var.create_vpc ? 2 : 0

  vpc_id = aws_vpc.forwarder[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.forwarder[count.index].id
  }

  tags = {
    Name = "${var.function_name}-private-${count.index + 1}"
  }
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc ? 2 : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = var.create_vpc ? 2 : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "forwarder" {
  count = var.create_vpc ? 1 : 0

  name_prefix = "${var.function_name}-"
  vpc_id      = aws_vpc.forwarder[0].id

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

data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for VPC configuration
locals {
  vpc_id             = var.create_vpc ? aws_vpc.forwarder[0].id : var.vpc_id
  subnet_ids         = var.create_vpc ? aws_subnet.private[*].id : data.aws_subnets.existing[0].ids
  security_group_ids = var.create_vpc ? [aws_security_group.forwarder[0].id] : [data.aws_security_group.existing[0].id]
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
  vpc_security_group_ids = local.security_group_ids
  vpc_subnet_ids         = local.subnet_ids

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
