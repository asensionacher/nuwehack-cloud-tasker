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
    cloudwatch     = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    events         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
  }
}

# Add here all the infraestructure logic

# DynamoDB

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