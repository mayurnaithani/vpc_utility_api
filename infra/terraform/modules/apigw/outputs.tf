output "apigw_api_id" {
  value = aws_api_gateway_rest_api.vpc_provisioning_api.id
}

output "apigw_arn" {
  value = aws_api_gateway_rest_api.vpc_provisioning_api.arn
}