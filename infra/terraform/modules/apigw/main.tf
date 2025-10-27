data "aws_cognito_user_pool" "corp_user_pool" {
  id = var.cognito_user_pool_id_in
}

data "aws_cognito_corp_user_pool_client" "corp_user_pool_client" {
  id           = var.cognito_corp_user_pool_client_id
  user_pool_id = var.cognito_user_pool_id
}

resource "aws_api_gateway_rest_api" "vpc_provisioning_api" {
  name        = "vpc_provisioning_api"
  description = "Public API to support VPC automation tasks"
}


data "aws_api_gateway_resource" "api_root" {
  rest_api_id = aws_api_gateway_rest_api.vpc_provisioning_api.id
  path        = "/"
}

resource "aws_api_gateway_authorizer" "api_cognito_auth" {
  name          = "apigw-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.vpc_provisioning_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [data.aws_cognito_user_pool.corp_user_pool.arn]
}

resource "aws_api_gateway_resource" "apigw_post_resource" {
  rest_api_id = aws_api_gateway_rest_api.vpc_provisioning_api.id
  parent_id   = data.aws_api_gateway_resource.api_root.id
  path_part   = "create"
}

# Request model for POST input validation
resource "aws_api_gateway_model" "apigw_post_request_model" {
  rest_api_id  = aws_api_gateway_rest_api.vpc_provisioning_api.id
  name         = "PostRequestModel"
  content_type = "application/json"
  schema = jsonencode({
    type     = "object"
    required = ["vpc_cidr", "subnet_cidr", "aws_region", "aws_account"]
    properties = {
      vpc_cidr    = { type = "string" }
      subnet_cidr = { type = "string" }
      aws_region  = { type = "string" }
      aws_account = { type = "string" }
    }
  })
}

# Request validator for POST
resource "aws_api_gateway_request_validator" "post_validator" {
  rest_api_id                 = aws_api_gateway_rest_api.vpc_provisioning_api.id
  name                        = "PostRequestValidator"
  validate_request_body       = true
  validate_request_parameters = false
}

# POST method definition
resource "aws_api_gateway_method" "apigw_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_provisioning_api.id
  resource_id   = aws_api_gateway_resource.apigw_post_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_cognito_auth.id
  request_models = {
    "application/json" = aws_api_gateway_model.apigw_post_request_model.name
  }
  request_validator_id = aws_api_gateway_request_validator.post_validator.id
}


resource "aws_api_gateway_integration" "apigw_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vpc_provisioning_api.id
  resource_id             = aws_api_gateway_resource.apigw_post_resource.id
  http_method             = aws_api_gateway_method.apigw_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region_in}:sqs:path/${var.aws_account_in}/${var.sqs_queue_in}"
  credentials             = var.sqs_role_apigw_in

  # Mapping template to add tracking_id
  request_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
{
  "request_id": "$context.requestId",
  "vpc_cidr": "$inputRoot.vpc_cidr",
  "subnet_cidr": "$inputRoot.subnet_cidr",
  "aws_region": "$inputRoot.aws_region",
  "aws_account": "$inputRoot.aws_account"
}
EOF
  }
}

resource "aws_api_gateway_resource" "apigw_get_resource" {
  rest_api_id = aws_api_gateway_rest_api.vpc_provisioning_api.id
  parent_id   = data.aws_api_gateway_resource.api_root.id
  path_part   = "info"
}

resource "aws_api_gateway_method" "apigw_get_method" {
  rest_api_id   = aws_api_gateway_rest_api.vpc_provisioning_api.id
  resource_id   = aws_api_gateway_resource.apigw_get_resource.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_cognito_auth.id

  request_parameters = {
    "method.request.querystring.request_id" = true
  }
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_in
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region_in}:${var.aws_account_in}:${aws_api_gateway_rest_api.vpc_provisioning_api.id}/*/${aws_api_gateway_method.apigw_get_method.http_method}${aws_api_gateway_resource.apigw_get_resource.path}"
}

resource "aws_api_gateway_integration" "apigw_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vpc_provisioning_api.id
  resource_id             = aws_api_gateway_resource.apigw_get_resource.id
  http_method             = aws_api_gateway_method.apigw_get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = var.get_vpc_lambda_arn_in
}


resource "aws_api_gateway_deployment" "vpc_provisoning_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.apigw_post_integration,
    aws_api_gateway_integration.apigw_get_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.vpc_provisioning_api.id
  stage_name  = "v1"
}
