output "vpc_lambda_arns" {
  for_each = local.deployment
  value    = aws_lambda_function.vpc_lambda[each.key].arn
}
