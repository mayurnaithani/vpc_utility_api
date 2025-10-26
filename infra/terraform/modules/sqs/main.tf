resource "aws_sqs_queue" "vpc_queue" {
  name = "vpc-request-queue"
}


data "aws_iam_policy_document" "sqs_policy" {
  statement {
    sid    = "AllowConsumeByWorkerLambda"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.lambda_role_arn_in]
    }

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]

    resources = [aws_sqs_queue.vpc_queue.arn]
  }
}

resource "aws_sqs_queue_policy" "vpc_queue_policy" {
  queue_url = aws_sqs_queue.vpc_queue.id
  policy    = data.aws_iam_policy_document.sqs_policy.json
}
