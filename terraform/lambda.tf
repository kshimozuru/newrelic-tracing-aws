data "archive_file" "api_gateway_handler" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/api-gateway"
  output_path = "${path.module}/api-gateway-handler.zip"
}

resource "aws_lambda_function" "api_gateway_handler" {
  filename         = data.archive_file.api_gateway_handler.output_path
  function_name    = "${var.project_name}-api-gateway-handler"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30

  source_code_hash = data.archive_file.api_gateway_handler.output_base64sha256

  # New Relic Lambda Layer for automatic instrumentation and log forwarding
  layers = [
    "arn:aws:lambda:${var.aws_region}:451483290750:layer:NewRelicNodeJS18X:96"
  ]

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.main.url
      NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
      NEW_RELIC_APP_NAME = "${var.project_name}-api-gateway"
      NEW_RELIC_LAMBDA_HANDLER = "index.handler"
      NEW_RELIC_USE_ESM = "false"
      NEW_RELIC_EXTENSION_SEND_FUNCTION_LOGS = "true"
      NEW_RELIC_DISTRIBUTED_TRACING_ENABLED = "true"
    }
  }

  tags = local.common_tags
}

data "archive_file" "sqs_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/sqs-processor"
  output_path = "${path.module}/sqs-processor.zip"
}

resource "aws_lambda_function" "sqs_processor" {
  filename         = data.archive_file.sqs_processor.output_path
  function_name    = "${var.project_name}-sqs-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 60

  source_code_hash = data.archive_file.sqs_processor.output_base64sha256

  # New Relic Lambda Layer for automatic instrumentation and log forwarding
  layers = [
    "arn:aws:lambda:${var.aws_region}:451483290750:layer:NewRelicNodeJS18X:96"
  ]

  environment {
    variables = {
      BATCH_JOB_QUEUE = aws_batch_job_queue.main.name
      BATCH_JOB_DEFINITION = aws_batch_job_definition.main.name
      NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
      NEW_RELIC_APP_NAME = "${var.project_name}-sqs-processor"
      NEW_RELIC_LAMBDA_HANDLER = "index.handler"
      NEW_RELIC_USE_ESM = "false"
      NEW_RELIC_EXTENSION_SEND_FUNCTION_LOGS = "true"
      NEW_RELIC_DISTRIBUTED_TRACING_ENABLED = "true"
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.sqs_processor.arn
  batch_size       = 1
}

data "archive_file" "step_function_lambda1" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/step-functions/lambda1"
  output_path = "${path.module}/step-function-lambda1.zip"
}

resource "aws_lambda_function" "step_function_lambda1" {
  filename         = data.archive_file.step_function_lambda1.output_path
  function_name    = "${var.project_name}-step-function-lambda1"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30

  source_code_hash = data.archive_file.step_function_lambda1.output_base64sha256

  # New Relic Lambda Layer for automatic instrumentation and log forwarding
  layers = [
    "arn:aws:lambda:${var.aws_region}:451483290750:layer:NewRelicNodeJS18X:96"
  ]

  environment {
    variables = {
      NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
      NEW_RELIC_APP_NAME = "${var.project_name}-step-function-lambda1"
      NEW_RELIC_LAMBDA_HANDLER = "index.handler"
      NEW_RELIC_USE_ESM = "false"
      NEW_RELIC_EXTENSION_SEND_FUNCTION_LOGS = "true"
      NEW_RELIC_DISTRIBUTED_TRACING_ENABLED = "true"
    }
  }

  tags = local.common_tags
}

data "archive_file" "step_function_lambda2" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/step-functions/lambda2"
  output_path = "${path.module}/step-function-lambda2.zip"
}

resource "aws_lambda_function" "step_function_lambda2" {
  filename         = data.archive_file.step_function_lambda2.output_path
  function_name    = "${var.project_name}-step-function-lambda2"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 30

  source_code_hash = data.archive_file.step_function_lambda2.output_base64sha256

  # New Relic Lambda Layer for automatic instrumentation and log forwarding
  layers = [
    "arn:aws:lambda:${var.aws_region}:451483290750:layer:NewRelicNodeJS18X:96"
  ]

  environment {
    variables = {
      NEW_RELIC_LICENSE_KEY = var.new_relic_license_key
      NEW_RELIC_APP_NAME = "${var.project_name}-step-function-lambda2"
      NEW_RELIC_LAMBDA_HANDLER = "index.handler"
      NEW_RELIC_USE_ESM = "false"
      NEW_RELIC_EXTENSION_SEND_FUNCTION_LOGS = "true"
      NEW_RELIC_DISTRIBUTED_TRACING_ENABLED = "true"
    }
  }

  tags = local.common_tags
}