resource "aws_sfn_state_machine" "main" {
  name     = "${var.project_name}-state-machine"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "New Relic tracing Step Functions"
    StartAt = "Lambda1"
    States = {
      Lambda1 = {
        Type     = "Task"
        Resource = aws_lambda_function.step_function_lambda1.arn
        Next     = "Lambda2"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
      Lambda2 = {
        Type     = "Task"
        Resource = aws_lambda_function.step_function_lambda2.arn
        End      = true
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
      }
    }
  })

  tags = local.common_tags
}