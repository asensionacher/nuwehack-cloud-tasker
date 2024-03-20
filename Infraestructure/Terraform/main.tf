terraform {
  required_version = "= 1.7.5"
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = local.region
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    apigatewayv2   = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    elasticache    = "http://localhost:4566"
    events         = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    kms            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    rds            = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    route53        = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}

# Add here all the infraestructure logic

# DynamoDB

# VPC gateway endpoint for DynamoDB. This will make sure our Lambda can access DynamoDB without going over the internet
resource "aws_vpc_endpoint" "dynamodb_vpce" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${local.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.route_table_private.id]
  policy            = data.aws_iam_policy_document.s3_endpoint_policy.json
}

resource "aws_dynamodb_table" "task_table" {

  name         = "TASKS"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "task_id"

  attribute {
    name = "task_name"
    type = "S"
  }

  attribute {
    name = "cron_expression"
    type = "S"
  }

  attribute {
    name = "task_id"
    type = "S"
  }

  global_secondary_index {
    name            = "TaksCron"
    hash_key        = "task_name"
    range_key       = "cron_expression"
    projection_type = "ALL"
  }

}

##############################################

# Lambdas

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.project}-vpc"
  }
}

resource "aws_subnet" "subnet_private" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.project}-subnet-private"
  }
}

resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.project}-route-table-private"
  }
}

resource "aws_route_table_association" "route_table_association_private" {
  subnet_id      = aws_subnet.subnet_private.id
  route_table_id = aws_route_table.route_table_private.id
}

resource "aws_default_network_acl" "default_network_acl" {
  default_network_acl_id = aws_vpc.vpc.default_network_acl_id
  subnet_ids             = [aws_subnet.subnet_private.id]

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.project}-default-network-acl"
  }
}

resource "aws_default_security_group" "default_security_group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project}-default-security-group"
  }
}

## Roles
resource "aws_iam_role" "LambdaRole" {
  name               = "LambdaRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "template_file" "lambdapolicy" {
  template = file("${path.module}/policy.json")
}

resource "aws_iam_policy" "LambdaPolicy" {
  name        = "LambdaPolicy"
  path        = "/"
  description = "IAM policy for Taks lambda functions"
  policy      = data.template_file.lambdapolicy.rendered
}

resource "aws_iam_role_policy_attachment" "LambdaRolePolicy" {
  role       = aws_iam_role.LambdaRole.name
  policy_arn = aws_iam_policy.LambdaPolicy.arn
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_vpc_access_execution" {
  role       = aws_iam_role.LambdaRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

## 

data "archive_file" "createScheduledTask" {
  type             = "zip"
  source_file      = "${path.module}/../lambda/createScheduledTask.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/src/createScheduledTask.zip"
}

resource "aws_lambda_function" "CreateTaskHandler" {

  function_name = "createScheduledTask"

  filename = data.archive_file.createScheduledTask.output_path

  handler = "createScheduledTask.lambda_handler"
  runtime = "python3.8"
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_private.id]
    security_group_ids = [aws_default_security_group.default_security_group.id]
  }
  environment {
    variables = {
      REGION     = local.region
      TASK_TABLE = aws_dynamodb_table.task_table.name
    }
  }

  source_code_hash = data.archive_file.createScheduledTask.output_base64sha256

  role = aws_iam_role.LambdaRole.arn

  timeout     = "5"
  memory_size = "128"

}

data "archive_file" "listScheduledTask" {
  type             = "zip"
  source_file      = "${path.module}/../lambda/listScheduledTask.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/src/listScheduledTask.zip"
}

resource "aws_lambda_function" "ListTaskHandler" {

  function_name = "listScheduledTask"

  filename = data.archive_file.listScheduledTask.output_path

  handler = "listScheduledTask.lambda_handler"
  runtime = "python3.8"
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_private.id]
    security_group_ids = [aws_default_security_group.default_security_group.id]
  }

  environment {
    variables = {
      REGION     = local.region
      TASK_TABLE = aws_dynamodb_table.task_table.name
    }
  }

  source_code_hash = data.archive_file.listScheduledTask.output_base64sha256

  role = aws_iam_role.LambdaRole.arn

  timeout     = "5"
  memory_size = "128"

}

data "archive_file" "executeScheduledTask" {
  type             = "zip"
  source_file      = "${path.module}/../lambda/executeScheduledTask.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/src/executeScheduledTask.zip"
}

resource "aws_lambda_function" "executeScheduledTaskHandler" {

  function_name = "executeScheduledTask"

  filename = data.archive_file.executeScheduledTask.output_path

  handler = "executeScheduledTask.lambda_handler"
  runtime = "python3.8"
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_private.id]
    security_group_ids = [aws_default_security_group.default_security_group.id]
  }

  environment {
    variables = {
      REGION     = local.region
      DST_BUCKET = local.bucket_name,
    }
  }

  source_code_hash = data.archive_file.executeScheduledTask.output_base64sha256

  role = aws_iam_role.LambdaRole.arn

  timeout     = "5"
  memory_size = "128"

}

##############################################

resource "aws_api_gateway_rest_api" "task_apigw" {
  name        = "task_apigw"
  description = "Tasks API Gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "createtask" {
  rest_api_id = aws_api_gateway_rest_api.task_apigw.id
  parent_id   = aws_api_gateway_rest_api.task_apigw.root_resource_id
  path_part   = "createtask"
}

resource "aws_api_gateway_resource" "listtask" {
  rest_api_id = aws_api_gateway_rest_api.task_apigw.id
  parent_id   = aws_api_gateway_rest_api.task_apigw.root_resource_id
  path_part   = "listtask"
}

resource "aws_api_gateway_resource" "every-minute" {
  rest_api_id = aws_api_gateway_rest_api.task_apigw.id
  parent_id   = aws_api_gateway_rest_api.task_apigw.root_resource_id
  path_part   = "every-minute"
}

resource "aws_api_gateway_method" "createtask" {
  rest_api_id   = aws_api_gateway_rest_api.task_apigw.id
  resource_id   = aws_api_gateway_resource.createtask.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "listtask" {
  rest_api_id   = aws_api_gateway_rest_api.task_apigw.id
  resource_id   = aws_api_gateway_resource.listtask.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "every-minute" {
  rest_api_id   = aws_api_gateway_rest_api.task_apigw.id
  resource_id   = aws_api_gateway_resource.every-minute.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "createtask-lambda" {
  rest_api_id = aws_api_gateway_rest_api.task_apigw.id
  resource_id = aws_api_gateway_method.createtask.resource_id
  http_method = aws_api_gateway_method.createtask.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"

  uri = aws_lambda_function.CreateTaskHandler.invoke_arn
}

resource "aws_api_gateway_integration" "listtask-lambda" {
  rest_api_id = aws_api_gateway_rest_api.task_apigw.id
  resource_id = aws_api_gateway_method.listtask.resource_id
  http_method = aws_api_gateway_method.listtask.http_method

  integration_http_method = "GET"
  type                    = "AWS_PROXY"

  uri = aws_lambda_function.ListTaskHandler.invoke_arn
}

resource "aws_api_gateway_integration" "every-minute-lambda" {
  rest_api_id = aws_api_gateway_rest_api.task_apigw.id
  resource_id = aws_api_gateway_method.every-minute.resource_id
  http_method = aws_api_gateway_method.every-minute.http_method

  integration_http_method = "GET"
  type                    = "AWS_PROXY"

  uri = aws_lambda_function.executeScheduledTaskHandler.invoke_arn
}

resource "aws_lambda_permission" "apigw-CreateTaskHandler" {

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CreateTaskHandler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.task_apigw.execution_arn}/*/POST/createtask"
}

resource "aws_lambda_permission" "apigw-ListTaskkHandler" {

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ListTaskHandler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.task_apigw.execution_arn}/*/GET/listtask"
}

resource "aws_lambda_permission" "apigw-executeScheduledTaskHandler" {

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.executeScheduledTaskHandler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.task_apigw.execution_arn}/*/GET/every-minute"
}

resource "aws_api_gateway_deployment" "taskapistageprod" {

  depends_on = [
    aws_api_gateway_integration.createtask-lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.task_apigw.id
  stage_name  = "prod"
}

##############################################

# S3

resource "aws_iam_policy" "lambda_policy" {
  name        = "executeScheduledTask_taskstorage_lambda_policy"
  description = "Policy for executeScheduledTask lambda to upload files to taskstorage."
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:CopyObject",
        "s3:HeadObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::taskstorage",
        "arn:aws:s3:::taskstorage/*"
      ]
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "terraform_lambda_iam_policy_basic_execution" {
  role       = aws_iam_role.LambdaRole.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_s3_bucket" "taskstorage" {
  bucket        = local.bucket_name
  force_destroy = true
}
# Define an account specific data source
data "aws_caller_identity" "current" {}
# Provision the KMS key
resource "aws_kms_key" "kms_key" {
  description             = "KMS key for S3  Bucket"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "${local.project}-prod-key-policy",
    Statement = concat([
      {
        Sid    = "Allow administration of the key",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" # allow the root user to administer the key but not use it
        },
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow use of the key",
        Effect = "Allow",
        Principal = {
          AWS = "${aws_iam_role.LambdaRole.arn}" # allow the lambda execution role to use the key but not administer it
        },
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*", "kms:CreateGrant"]
        Resource = "*"
      }]
    )
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse_config" {
  bucket = aws_s3_bucket.taskstorage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.kms_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true # The bucket key reduces encryption costs by lowering calls to AWS KMS.
  }
}

# Endpoint policy for the S3 endpoint
data "aws_iam_policy_document" "s3_endpoint_policy" {
  statement {
    actions   = ["s3:putObject", "s3:getObject"]
    resources = ["${aws_s3_bucket.taskstorage.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [aws_iam_role.LambdaRole.arn] # only allow access to this endpoint from the Lambda function
    }
  }
}

# VPC gateway endpoint for S3. This will make sure our Lambda can access S3 without going over the internet
resource "aws_vpc_endpoint" "s3_vpce" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.route_table_private.id]
  policy            = data.aws_iam_policy_document.s3_endpoint_policy.json
}

# Define an S3 bucket policy that only allows access from the VPC S3 Gateway endpoint
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "DenyAllUnlessFromSpecificVPCe" # deny everybody not coming in via the VPC endpoint
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["${aws_iam_role.LambdaRole.arn}"]
    }

    actions = ["s3:*"]

    resources = [
      "${aws_s3_bucket.taskstorage.arn}/*", # allow access to all objects in the bucket
      "${aws_s3_bucket.taskstorage.arn}"
    ]

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"
      values = [
        aws_vpc_endpoint.s3_vpce.id # only allow access when this VPC S3 Gateway endpoint is used
      ]
    }
  }
}

# Attach the S3 bucket policy to the S3 bucket
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.taskstorage.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# Add an alias to the KMS key
resource "aws_kms_alias" "kms_alias" {
  name          = "alias/${local.project}-kms-key" # add an alias for easier identification in the console
  target_key_id = aws_kms_key.kms_key.key_id
}

##############################################

# EventBridge

resource "aws_cloudwatch_event_connection" "this" {
  name        = "api-key"
  description = "Used as a simple key-value header authentication"

  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "X-Auth-Token"
      value = "test"
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "this" {
  name        = "audit-user-access"
  description = "Records user access data for auditing purposes"

  invocation_endpoint              = "http://localhost:4566/restapis/${aws_api_gateway_deployment.taskapistageprod.rest_api_id}/prod/_user_request_/every-minute"
  http_method                      = "GET"
  invocation_rate_limit_per_second = 1
  connection_arn                   = aws_cloudwatch_event_connection.this.arn
}

resource "aws_cloudwatch_event_rule" "this" {
  name        = "once-every-minute"
  description = "Run once every minute"

  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_event_target" "this" {
  target_id = "audit-user-access-once-every-minute"

  rule     = aws_cloudwatch_event_rule.this.name
  arn      = aws_cloudwatch_event_api_destination.this.arn
  role_arn = aws_iam_role.this.arn
}

resource "aws_iam_role" "this" {
  name = "once-every-minute-cron-executor"

  managed_policy_arns = [aws_iam_policy.this.arn]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "this" {
  name = "once-every-minute-cron-executor"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "events:InvokeApiDestination"
        Effect   = "Allow"
        Resource = aws_cloudwatch_event_api_destination.this.arn
      },
    ]
  })
}