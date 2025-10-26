resource "aws_dynamodb_table" "vpc_status_table" {
  name         = var.table_name_in
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"
  range_key    = "vpc_cidr"
  attribute {
    name = "request_id"
    type = "S"
  }
  attribute {
    name = "vpc_id"
    type = "S"
  }
  attribute {
    name = "vpc_cidr"
    type = "S"
  }
  attribute {
    name = "aws_region"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "subnet_ids"
    type = "SS"
  }
  attribute {
    name = "aws_account"
    type = "S"
  }
  attribute {
    name = "reason"
    type = "S"
  }
  attribute {
    name = "creation_time"
    type = "S"
  }
  global_secondary_index {
    name               = "VPC_GSI"
    hash_key           = "aws_region"
    range_key          = "aws_account"
    projection_type    = "INCLUDE"
    non_key_attributes = ["vpc_cidr"]
  }
  tags = var._in
}
