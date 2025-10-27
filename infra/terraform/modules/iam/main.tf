data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "vpc_lambda_role" {
  name               = "vpc-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    effect    = "Allow"
    actions   = [
      "sqs:GetQueueAttributes",
      "sqs:GetMessage"
    ]
    resources = [*]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
    resources = [var.vpc_ddb_table_arn_in]
  }
}


resource "aws_iam_policy" "vpc_lambda_policy" {
  name        = "vpc_lambda_policy"
  description = "IAM policy to be used by our VPC lambdas"
  policy      = data.aws_iam_policy_document.policy.json
}

resource "aws_iam_role_policy_attachment" "vpc_lambda_policy_attach" {
  role       = aws_iam_role.vpc_lambda_role.name
  policy_arn = aws_iam_policy.vpc_lambda_policy.arn
}