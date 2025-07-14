resource "aws_ecs_cluster" "batch_cluster" {
  name = "${var.project_name}-batch-cluster"
  tags = local.common_tags
}

resource "aws_batch_compute_environment" "main" {
  compute_environment_name = "${var.project_name}-compute-env"
  type                     = "MANAGED"
  state                    = "ENABLED"

  compute_resources {
    type                 = "FARGATE"
    max_vcpus           = 10
    security_group_ids  = [aws_security_group.batch.id]
    subnets            = [aws_subnet.public.id]
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service_role]
}

resource "aws_batch_job_queue" "main" {
  name     = "${var.project_name}-job-queue"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.main.arn
  }
  tags = local.common_tags
}

resource "aws_batch_job_definition" "main" {
  name = "${var.project_name}-job-definition"
  type = "container"
  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image = "${aws_ecr_repository.batch_job.repository_url}:latest"
    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }
    resourceRequirements = [
      {
        type  = "VCPU"
        value = "0.25"
      },
      {
        type  = "MEMORY"
        value = "512"
      }
    ]
    executionRoleArn = aws_iam_role.batch_execution_role.arn
    jobRoleArn      = aws_iam_role.batch_job_role.arn
    networkConfiguration = {
      assignPublicIp = "ENABLED"
    }
    environment = [
      {
        name  = "NEW_RELIC_LICENSE_KEY"
        value = var.new_relic_license_key
      },
      {
        name  = "NEW_RELIC_APP_NAME"
        value = "${var.project_name}-batch-job"
      },
      {
        name  = "STATE_MACHINE_ARN"
        value = aws_sfn_state_machine.main.arn
      }
    ]
  })

  retry_strategy {
    attempts = 1
  }

  timeout {
    attempt_duration_seconds = 600
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "batch_job" {
  name                 = "${var.project_name}-batch-job"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = local.common_tags
}