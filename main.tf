terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.24.0"
    }
  }

  backend "s3" {
    bucket = "tf-state-lambda-upload-document"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}


data "aws_iam_policy_document" "lambda_role_policy" {
  statement {
    effect = "Allow"


    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }


    actions = [
      "sts:AssumeRole"
    ]
  }
}


data "aws_iam_policy_document" "s3_access_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::imoveis-financiamentos-docs",
      "arn:aws:s3:::imoveis-financiamentos-docs/*"
    ]
  }
}


resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_policy.json
}




resource "aws_iam_role_policy" "s3_access_policy_attachment" {
  name   = "s3_access_policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.s3_access_policy.json
}


resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  # The ARN for the AWSLambdaBasicExecutionRole managed policy
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.arn
}




data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_function.zip"
}


resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_document_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}


resource "aws_lambda_function" "upload_document_lambda" {
  handler       = "main.handler"
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "upload_document_lambda"
  architectures = ["arm64"]

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.11"
}



resource "aws_api_gateway_rest_api" "proxy_lambda" {
  name        = "upload_document_api_imoveis"
  description = "API Gateway for Upload Document Lambda Function"

  binary_media_types = [
    "multipart/form-data",
    "application/pdf",
    "text/plain",
    "application/msword",
    "application/ms-excel",
  ]
}


resource "aws_api_gateway_resource" "name" {
  rest_api_id = aws_api_gateway_rest_api.proxy_lambda.id
  parent_id   = aws_api_gateway_rest_api.proxy_lambda.root_resource_id
  path_part   = "upload-document"
}

resource "aws_api_gateway_method" "proxy_lambda_method" {
  rest_api_id   = aws_api_gateway_rest_api.proxy_lambda.id
  resource_id   = aws_api_gateway_resource.name.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.proxy_lambda.id
  resource_id = aws_api_gateway_resource.name.id
  http_method = aws_api_gateway_method.proxy_lambda_method.http_method


  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.upload_document_lambda.invoke_arn
}


resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.proxy_lambda.id
  depends_on = [ aws_api_gateway_integration.proxy_lambda_integration ]
}


resource "aws_api_gateway_stage" "stage" {
  stage_name = "TESTE"
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id = aws_api_gateway_rest_api.proxy_lambda.id
}

