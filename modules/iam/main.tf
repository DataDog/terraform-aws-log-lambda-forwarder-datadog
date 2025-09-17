# IAM Role for the Forwarder Lambda
resource "aws_iam_role" "forwarder_role" {
  name = "${var.function_name}-${var.region}-Role"
  path = var.iam_role_path

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn != null ? var.permissions_boundary_arn : null

  tags = var.tags
}

# IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.forwarder_role.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.forwarder_role.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IAM Policy for the Forwarder
resource "aws_iam_role_policy" "forwarder_policy" {
  name = "${var.function_name}-${var.region}-RolePolicy"
  role = aws_iam_role.forwarder_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = flatten([
      # S3 permissions for forwarder bucket
      var.s3_bucket_permissions ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = var.forwarder_bucket_arn != null ? "${var.forwarder_bucket_arn}/*" : "arn:${var.partition}:s3:::${var.dd_forwarder_existing_bucket_name}/*"
        },
      ] : [],

      var.s3_bucket_permissions ? [
        {
          Effect   = "Allow"
          Action   = ["s3:ListBucket"]
          Resource = var.forwarder_bucket_arn != null ? var.forwarder_bucket_arn : "arn:${var.partition}:s3:::${var.dd_forwarder_existing_bucket_name}"
          Condition = {
            StringLike = {
              "s3:prefix" = [
                "failed_events/*",
                "cache/*"
              ]
            }
          }
        }
      ] : [],

      # S3 read access for logs
      [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject"]
          Resource = "*"
        }
      ],

      # KMS permissions for encrypted S3 buckets
      [
        {
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = "*"
        }
      ],

      # Secrets Manager permissions
      var.dd_api_key_ssm_parameter_name == null && var.dd_api_key_secret_arn != null ? [
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = var.dd_api_key_secret_arn
        }
      ] : [],

      # SSM Parameter Store permissions
      var.dd_api_key_ssm_parameter_name != null ? [
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:GetParametersByPath"
          ]
          Resource = "*"
        }
      ] : [],

      # Tag fetching permissions (Lambda and Step Functions)
      coalesce(var.dd_fetch_lambda_tags, false) || coalesce(var.dd_fetch_step_functions_tags, false) ? [
        {
          Effect   = "Allow"
          Action   = ["tag:GetResources"]
          Resource = "*"
        }
      ] : [],

      # Log Group tag permissions
      coalesce(var.dd_fetch_log_group_tags, false) ? [
        {
          Effect   = "Allow"
          Action   = ["logs:ListTagsForResource"]
          Resource = "*"
        }
      ] : [],

      # VPC permissions
      var.dd_use_vpc ? [
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface"
          ]
          Resource = "*"
        }
      ] : [],

      # Additional target Lambda permissions
      length(var.additional_target_lambda_arns) > 0 ? [
        {
          Effect   = "Allow"
          Action   = ["lambda:InvokeFunction"]
          Resource = var.additional_target_lambda_arns
        }
      ] : []
    ])
  })
}
