data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  task_execution_role_arn = var.task_execution_role_arn != "" ? var.task_execution_role_arn : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.task_execution_role_name}"
  task_role_arn           = var.task_role_arn != "" ? var.task_role_arn : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.task_role_name}"
}

resource "aws_cloudwatch_log_group" "migration" {
  name              = "/ecs/${var.project_name}-db-migrator"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "migration" {
  name = var.cluster_name
}

resource "aws_ecs_task_definition" "db_migrator" {
  family                   = "${var.project_name}-db-migrator"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "db-migrator"
      image     = var.migration_image
      essential = true
      environment = [
        {
          name  = "DB_HOST"
          value = var.db_host
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        }
      ]
      secrets = [
        {
          name      = "DB_USER"
          valueFrom = var.db_user_secret_arn
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = var.db_password_secret_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.migration.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "db-migrator"
        }
      }
    }
  ])
}
