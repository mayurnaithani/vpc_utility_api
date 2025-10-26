variable "table_name_in" {
  type        = string
  description = "name of dynamoDB table to be created"
}

variable "tags_in" {
  type        = map(string)
  description = "Tags to be applied to DynamoDB table"
}