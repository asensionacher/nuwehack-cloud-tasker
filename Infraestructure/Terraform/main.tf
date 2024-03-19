terraform {
  required_version = "= 1.7.5"
}

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
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

resource "aws_api_gateway_rest_api" "schedule_apigw" {
  name        = "schedule_apigw"
  description = "Schedule API Gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "task" {
  rest_api_id = aws_api_gateway_rest_api.schedule_apigw.id
  parent_id   = aws_api_gateway_rest_api.schedule_apigw.root_resource_id
  path_part   = "createtask"
}

resource "aws_api_gateway_method" "createtask" {
  rest_api_id   = aws_api_gateway_rest_api.schedule_apigw.id
  resource_id   = aws_api_gateway_resource.task.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_iam_role" "ProductLambdaRole" {
  name               = "ProductLambdaRole"
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

data "template_file" "productlambdapolicy" {
  template = "${file("${path.module}/policy.json")}"
}

resource "aws_iam_policy" "ProductLambdaPolicy" {
  name        = "ProductLambdaPolicy"
  path        = "/"
  description = "IAM policy for Product lambda functions"
  policy      = data.template_file.productlambdapolicy.rendered
}

resource "aws_iam_role_policy_attachment" "ProductLambdaRolePolicy" {
  role       = aws_iam_role.ProductLambdaRole.name
  policy_arn = aws_iam_policy.ProductLambdaPolicy.arn
}

resource "aws_lambda_function" "CreateTaskHandler" {

  function_name = "createScheduledTask"

  filename = "../lambda/product_lambda.zip"

  handler = "createScheduledTask.lambda_handler"
  runtime = "python3.8"

  environment {
    variables = {
      REGION        = "us-east-1"
      TASK_TABLE = aws_dynamodb_table.task_table.name
   }
  }

  source_code_hash = filebase64sha256("../lambda/product_lambda.zip")

  role = aws_iam_role.ProductLambdaRole.arn

  timeout     = "5"
  memory_size = "128"

}

resource "aws_api_gateway_integration" "createtask-lambda" {

  rest_api_id = aws_api_gateway_rest_api.schedule_apigw.id
  resource_id = aws_api_gateway_method.createtask.resource_id
  http_method = aws_api_gateway_method.createtask.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"

  uri = aws_lambda_function.CreateTaskHandler.invoke_arn
}

resource "aws_lambda_permission" "apigw-CreateTaskHandler" {

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CreateTaskHandler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.schedule_apigw.execution_arn}/*/POST/createtask"
}

resource "aws_api_gateway_deployment" "productapistageprod" {

  depends_on = [
    aws_api_gateway_integration.createtask-lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.schedule_apigw.id
  stage_name = "prod"
}

output "api" {
  value = aws_api_gateway_deployment.productapistageprod.invoke_url
}

