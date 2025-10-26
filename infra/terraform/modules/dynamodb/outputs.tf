output "vpc_status_table" {
  value = aws_dynamodb_table.vpc_status_table.name
}