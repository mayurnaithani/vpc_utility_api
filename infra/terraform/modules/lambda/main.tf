locals {
  lambda = {
    get = {
      name        = get_vpc_function
      source_dir  = "${path.root}/api_ressources/aws_lambda/get_vpc_lambda"
      output_path = "${path.module}/get_vpc_lambda.zip"
      handler     = "get_vpc_lambda.lambda_handler"
    }
    post = {
      name        = create_vpc_function
      source_dir  = "${path.root}/api_ressources/aws_lambda/create_vpc_lambda"
      output_path = "${path.module}/create_vpc_lambda.zip"
      handler     = "create_vpc_lambda.lambda_handler"
    }
  }
}


data "archive_file" "lambda_zips" {
  for_each    = local.lambda
  type        = "zip"
  source_dir  = = each.value.source_dir
  output_path = each.value.output_path
}

resource "aws_cloudwatch_log_group" "vpc_lambda_log_group" {
  for_each          = local.lambda
  name              = "/aws/lambda/${each.value.name}"
  retention_in_days = 60
}

resource "aws_lambda_function" "vpc_lambda" {
  for_each      = local.lambda
  function_name = each.value.name
  filename      = each.value.output_path
  handler       = each.value.handler
  runtime       = "python3.12"
  role          = var.lambda_role_in

  environment {
    vpc_info_table = var.vpc_info_table_in
  }
}


resource "aws_lambda_event_source_mapping" "vpc_lambda_sqs_mapping" {
  event_source_arn = var.sqs_arn_in
  function_name    = aws_lambda_function.vpc_lambda['post'].arn
  batch_size       = 1
  depends_on       = [aws_lambda_function.vpc_lambda]
}
