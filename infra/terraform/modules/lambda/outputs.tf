output "get_vpc_lambda_arn" {
  value    = aws_lambda_function.vpc_lambda['get'].arn
}
