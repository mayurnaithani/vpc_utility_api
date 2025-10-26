variable "queue_name_in" {
  type        = string
  description = "Name of the SQS queue to be created"
}

variable "lambda_role_arn_in" {
  type        = string
  description = "ARN of PUT lambda to be added to SQS resource policy"
}