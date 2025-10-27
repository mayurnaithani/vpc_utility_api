output "queue_arn" {
  value = aws_sqs_queue.vpc_queue.arn
}

output "queue_name" {
  value = aws_sqs_queue.vpc_queue.name
}