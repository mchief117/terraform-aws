terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.21.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

data "archive_file" "checkCert-zip" {
  type = "zip"
  source_file  = "${path.module}/checkCert.py"
  output_path = "${path.module}/checkCert.zip"
}

resource "aws_iam_role" "lambda-iam" {
  name               = "lambda-iam"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": {
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Effect": "Allow"
  }
}
POLICY
}



resource "aws_lambda_function" "terraform_lambda" {
  filename      = data.archive_file.checkCert-zip.output_path
  function_name = "checkCert-function"
  role          = aws_iam_role.lambda-iam.arn
  handler       = "checkCert.checkCert_handler"
  runtime = "python3.9"
  publish = true
}

resource "aws_apigatewayv2_api" "terraform_lambda-api" {
  name          = "v2-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda-stage" {
  api_id      = aws_apigatewayv2_api.terraform_lambda-api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda-integration" {
  api_id               = aws_apigatewayv2_api.terraform_lambda-api.id
  integration_type     = "AWS_PROXY"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.terraform_lambda.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.terraform_lambda-api.id
  route_key = "GET /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda-integration.id}"
}

resource "aws_lambda_permission" "lambda-apigw-permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.terraform_lambda-api.execution_arn}/*/*/*"
}
