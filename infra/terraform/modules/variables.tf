### Variables for DynamoDB module ###
variable "ddb_table" {}
variable "ddb_tags" {}

### Variables for SQS module ###
variable "queue_name" {}
#variable "lambda_role_arn" {}

### Variables for APIGW module ###
variable "api_name" {}
variable "cognito_user_pool_id" {}
variable "aws_region" {}
variable "aws_account" {}

### Variables for IAM module ###
#variable "sqs_queue.arn" {}
#variable "vpc_ddb_table_arn" {}

### Variables for Lambda module ###
variable "lambda_role_arn" {}
variable "vpc_info_table_name" {}
variable "vpc_info_table_name" {}
variable "sqs_arn" {}