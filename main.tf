terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.21.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "archive_file" "checkCert-zip" {
  type = "zip"
  //source_file = "checkCert.py"
  source_file = "${path.module}/checkCert.py"
  output_path = "${path.module}/checkCert.zip"
}

resource "aws_iam_role" "lambda_iam" {
  name               = "lambda-iam-role"
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

resource "aws_iam_role_policy_attachment" "lambda_iam_policy" {
  role       = aws_iam_role.lambda_iam.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


#Define Variables for Lambda Function
resource "aws_lambda_function" "terraform_lambda" {
  //filename         = "${path.module}/Fearless_final_copy/checkCert.zip"
  filename      = data.archive_file.checkCert-zip.output_path
  function_name = "checkCert-function"
  role          = aws_iam_role.lambda_iam.arn
  handler       = "checkCert.checkCert_handler"
  //source_code_hash = data.archive_file.checkCert-zip.output_path
  runtime = "python3.9"
  publish = true
}

resource "aws_apigatewayv2_api" "terraform_lambda-api" {
  name          = "v2-http-api"
  protocol_type = "HTTP"
}


#Map Api gateway to lambda function
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.terraform_lambda-api.id
  integration_type       = "AWS_PROXY"
  connection_type        = "INTERNET"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.terraform_lambda.invoke_arn
  passthrough_behavior   = "WHEN_NO_MATCH" //?
  payload_format_version = "2.0"
}

#Map 
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.terraform_lambda-api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "lambda-stage" {
  api_id = aws_apigatewayv2_api.terraform_lambda-api.id
  name        = "$default"
  //name        = "live"
  auto_deploy = true
}

resource "aws_apigatewayv2_deployment" "lambda_deploy" {
  api_id      = aws_apigatewayv2_api.terraform_lambda-api.id
  description = "API Deployment"
  triggers = {
    redeployment = sha1(join(",", tolist([
      jsonencode(aws_apigatewayv2_integration.lambda_integration),
      jsonencode(aws_apigatewayv2_route.lambda_route),
    ])))
  }

  lifecycle {
    create_before_destroy = true
  }
}

#Define Permission to invoke Lambda function
resource "aws_lambda_permission" "lambda-apigw-permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_lambda.arn
  principal     = "apigateway.amazonaws.com"
  //source_arn    = "${aws_apigatewayv2_api.terraform_lambda-api.execution_arn}/${aws_apigatewayv2_route.lambda_route.route_key}"
}

#Output URL
output "invoke_url" {
  value = aws_apigatewayv2_stage.lambda-stage.invoke_url
}
