output "iam_role" {
  value = aws_iam_role.iam_for_lambda.name
}

output "function_arn" {
  value = aws_lambda_function.lambda.arn
}

output "function_name" {
  value = aws_lambda_function.lambda.function_name
}

