output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_deployment.main.invoke_url}/trace"
}

output "sqs_queue_url" {
  description = "SQS Queue URL"
  value       = aws_sqs_queue.main.url
}

output "batch_job_queue" {
  description = "Batch Job Queue name"
  value       = aws_batch_job_queue.main.name
}

output "step_functions_arn" {
  description = "Step Functions State Machine ARN"
  value       = aws_sfn_state_machine.main.arn
}

output "ecr_repository_url" {
  description = "ECR Repository URL for Batch job"
  value       = aws_ecr_repository.batch_job.repository_url
}