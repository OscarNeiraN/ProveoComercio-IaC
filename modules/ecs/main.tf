data "aws_iam_policy_document" "ecs_task_execution" {
  count = var.create_iam_roles ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  existing_task_role_name          = var.task_role_name != "" ? var.task_role_name : var.task_execution_role_name
  existing_task_execution_role_arn = var.task_execution_role_arn != "" ? var.task_execution_role_arn : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.task_execution_role_name}"
  existing_task_role_arn           = var.task_role_arn != "" ? var.task_role_arn : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${local.existing_task_role_name}"
  execution_role_arn               = var.create_iam_roles ? aws_iam_role.ecs_task_execution[0].arn : local.existing_task_execution_role_arn
  task_role_arn                    = var.create_iam_roles ? aws_iam_role.ecs_task[0].arn : local.existing_task_role_arn
}

resource "aws_iam_role" "ecs_task_execution" {
  count              = var.create_iam_roles ? 1 : 0
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution[0].json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  count      = var.create_iam_roles ? 1 : 0
  role       = aws_iam_role.ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  count              = var.create_iam_roles ? 1 : 0
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution[0].json
}

data "aws_iam_policy_document" "ecs_task_sqs" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ChangeMessageVisibility"
    ]

    resources = [var.sqs_queue_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_sqs" {
  count  = var.create_iam_roles ? 1 : 0
  name   = "${var.project_name}-ecs-task-sqs"
  role   = aws_iam_role.ecs_task[0].id
  policy = data.aws_iam_policy_document.ecs_task_sqs.json
}

data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      var.db_user_secret_arn,
      var.db_password_secret_arn,
      var.jwt_secret_arn,
      var.smtp_user_secret_arn,
      var.smtp_password_secret_arn
    ]
  }
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  count  = var.create_iam_roles ? 1 : 0
  name   = "${var.project_name}-ecs-execution-secrets"
  role   = aws_iam_role.ecs_task_execution[0].id
  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true
      portMappings = [
        {
          containerPort = var.frontend_port
          hostPort      = var.frontend_port
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "BACKEND_UPSTREAM"
          value = var.backend_upstream
        },
        {
          name  = "BACKEND_RESOLVER"
          value = var.backend_resolver
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "frontend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      essential = true
      portMappings = [
        {
          containerPort = var.backend_port
          hostPort      = var.backend_port
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:${var.backend_port}/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = tostring(var.backend_port)
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DB_HOST"
          value = var.db_host
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "SMTP_HOST"
          value = var.smtp_host
        },
        {
          name  = "SMTP_PORT"
          value = tostring(var.smtp_port)
        },
        {
          name  = "SMTP_SECURE"
          value = tostring(var.smtp_secure)
        },
        {
          name  = "MAIL_FROM"
          value = var.mail_from
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
        },
        {
          name  = "FRONTEND_URL"
          value = var.frontend_url
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
        },
        {
          name      = "JWT_SECRET"
          valueFrom = var.jwt_secret_arn
        },
        {
          name      = "SMTP_USER"
          valueFrom = var.smtp_user_secret_arn
        },
        {
          name      = "SMTP_PASSWORD"
          valueFrom = var.smtp_password_secret_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = local.execution_role_arn
  task_role_arn            = local.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.backend_image
      essential = true
      command   = ["node", "worker.js"]
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DB_HOST"
          value = var.db_host
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "SMTP_HOST"
          value = var.smtp_host
        },
        {
          name  = "SMTP_PORT"
          value = tostring(var.smtp_port)
        },
        {
          name  = "SMTP_SECURE"
          value = tostring(var.smtp_secure)
        },
        {
          name  = "MAIL_FROM"
          value = var.mail_from
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
        },
        {
          name  = "SQS_VISIBILITY_TIMEOUT_SECONDS"
          value = "300"
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
        },
        {
          name      = "SMTP_USER"
          valueFrom = var.smtp_user_secret_arn
        },
        {
          name      = "SMTP_PASSWORD"
          valueFrom = var.smtp_password_secret_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "worker"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_metric_alarm" "frontend_5xx" {
  alarm_name          = "${var.project_name}-frontend-5xx"
  alarm_description   = "5xx del frontend durante un deploy: si se dispara, ECS revierte el servicio solo"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.frontend_alb_arn_suffix
    TargetGroup  = var.frontend_target_group_arn_suffix
  }
}

resource "aws_ecs_service" "frontend" {
  name                              = "${var.project_name}-frontend-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.frontend.arn
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  desired_count                     = var.frontend_desired_count
  health_check_grace_period_seconds = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Ademas del health check del contenedor, mira la tasa de 5xx real del ALB durante
  # el deploy. Si el contenedor arranca "sano" pero la app tira errores con trafico
  # real, esto tambien dispara el rollback automatico (el circuit breaker solo no lo detecta).
  alarms {
    enable      = true
    rollback    = true
    alarm_names = [aws_cloudwatch_metric_alarm.frontend_5xx.alarm_name]
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.frontend_security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name   = "frontend"
    container_port   = var.frontend_port
  }

  depends_on = [aws_ecs_service.backend]
}

resource "aws_appautoscaling_target" "frontend" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.frontend_max_capacity
  min_capacity       = var.frontend_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-frontend-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend[0].resource_id
  scalable_dimension = aws_appautoscaling_target.frontend[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_utilization
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_5xx" {
  alarm_name          = "${var.project_name}-backend-5xx"
  alarm_description   = "5xx del backend durante un deploy: si se dispara, ECS revierte el servicio solo"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.backend_alb_arn_suffix
    TargetGroup  = var.backend_target_group_arn_suffix
  }
}

resource "aws_ecs_service" "backend" {
  name                              = "${var.project_name}-backend-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.backend.arn
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  desired_count                     = var.backend_desired_count
  health_check_grace_period_seconds = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  alarms {
    enable      = true
    rollback    = true
    alarm_names = [aws_cloudwatch_metric_alarm.backend_5xx.alarm_name]
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.backend_security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "backend"
    container_port   = var.backend_port
  }
}

resource "aws_ecs_service" "worker" {
  name             = "${var.project_name}-worker-service"
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.worker.arn
  launch_type      = "FARGATE"
  platform_version = "LATEST"
  desired_count    = var.worker_desired_count

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.worker_security_group_ids
    assign_public_ip = false
  }
}

resource "aws_appautoscaling_target" "backend" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.backend_max_capacity
  min_capacity       = var.backend_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "backend_cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-backend-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend[0].resource_id
  scalable_dimension = aws_appautoscaling_target.backend[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_utilization
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_target" "worker" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.worker_max_capacity
  min_capacity       = var.worker_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "worker_queue" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-worker-sqs"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker[0].resource_id
  scalable_dimension = aws_appautoscaling_target.worker[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker[0].service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions {
        name  = "QueueName"
        value = var.sqs_queue_name
      }
    }

    target_value       = var.worker_queue_messages_per_task
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
