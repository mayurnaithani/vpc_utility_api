module "dynamodb" {
  source        = "./dynamodb"
  table_name_in = var.ddb_table
  tags_in       = var.ddb_tags
}

module "iam" {
  source               = "./iam"
  vpc_ddb_table_arn_in = module.dynamodb.vpc_status_table_arn
}

module "sqs" {
  source             = "./sqs"
  queue_name_in      = var.queue_name
  lambda_role_arn_in = module.iam.vpc_role_arn
}

module "lambda" {
  source            = "./lambda"
  lambda_role_in    = module.iam.vpc_role_arn
  vpc_info_table_in = module.dynamodb.vpc_status_table
  sqs_arn_in        = module.sqs.queue_arn 
}

module "apigw" {
  source                  = "./apigw"
  api_name_in             = var.api_name
  cognito_user_pool_id_in = var.cognito_user_pool_id 
  get_vpc_lambda_arn_in   = module.lambda.get_vpc_lambda_arn
  aws_region_in           = var.aws_region
  aws_account_in          = var.aws_account
  sqs_queue_in            = module.sqs.queue_name
  sqs_role_apigw_in       = module.iam.vpc_role_arn
  lambda_in               = module.lambda.get_vpc_lambda_name
}
