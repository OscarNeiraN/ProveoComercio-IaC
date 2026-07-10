resource "aws_security_group" "alb" {
  name        = lower("${var.project_name}-alb-sg")
  description = "Public ALB security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = lower("${var.project_name}-alb-sg")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "ecs" {
  name        = lower("${var.project_name}-ecs-sg")
  description = "Private ECS Fargate tasks security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = lower("${var.project_name}-ecs-sg")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "frontend_ecs" {
  name        = lower("${var.project_name}-frontend-ecs-sg")
  description = "Private frontend ECS Fargate tasks security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = lower("${var.project_name}-frontend-ecs-sg")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "worker_ecs" {
  name        = lower("${var.project_name}-worker-ecs-sg")
  description = "Private worker ECS Fargate tasks security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = lower("${var.project_name}-worker-ecs-sg")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "db" {
  name        = lower("${var.project_name}-db-sg")
  description = "Private RDS MySQL security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = lower("${var.project_name}-db-sg")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "backend_alb" {
  name        = lower("${var.project_name}-backend-alb-sg")
  description = "Private backend ALB security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = lower("${var.project_name}-backend-alb-sg")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "migration" {
  name        = lower("${var.project_name}-migration-sg")
  description = "Temporary migration clients inside the VPC"
  vpc_id      = var.vpc_id

  tags = {
    Name = lower("${var.project_name}-migration-sg")
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Internet HTTP to public ALB"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to frontend tasks"
  referenced_security_group_id = aws_security_group.frontend_ecs.id
  from_port                    = var.frontend_port
  to_port                      = var.frontend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_frontend" {
  security_group_id            = aws_security_group.frontend_ecs.id
  description                  = "Frontend traffic from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.frontend_port
  to_port                      = var.frontend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "backend_alb_from_ecs" {
  security_group_id            = aws_security_group.backend_alb.id
  description                  = "Frontend tasks to private backend ALB"
  referenced_security_group_id = aws_security_group.frontend_ecs.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_backend_alb" {
  security_group_id            = aws_security_group.frontend_ecs.id
  description                  = "Frontend tasks to private backend ALB"
  referenced_security_group_id = aws_security_group.backend_alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "frontend_https_outbound" {
  security_group_id = aws_security_group.frontend_ecs.id
  description       = "Frontend tasks to AWS APIs over HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "backend_alb_to_ecs" {
  security_group_id            = aws_security_group.backend_alb.id
  description                  = "Private backend ALB to backend tasks"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.backend_port
  to_port                      = var.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_backend_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Private backend ALB to backend tasks"
  referenced_security_group_id = aws_security_group.backend_alb.id
  from_port                    = var.backend_port
  to_port                      = var.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_db" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Fargate tasks to RDS MySQL"
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "migration_to_db" {
  security_group_id            = aws_security_group.migration.id
  description                  = "Temporary migration client to RDS MySQL"
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "migration_https_outbound" {
  security_group_id = aws_security_group.migration.id
  description       = "Temporary migration client to AWS APIs over HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_tcp_outbound" {
  for_each = toset(["80", "443", "465", "587"])

  security_group_id = aws_security_group.ecs.id
  description       = "Private task outbound TCP ${each.value}"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "worker_to_db" {
  security_group_id            = aws_security_group.worker_ecs.id
  description                  = "Worker tasks to RDS MySQL"
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "worker_tcp_outbound" {
  for_each = toset(["80", "443", "465", "587"])

  security_group_id = aws_security_group.worker_ecs.id
  description       = "Private worker outbound TCP ${each.value}"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_ecs" {
  security_group_id            = aws_security_group.db.id
  description                  = "Only ECS Fargate tasks can reach MySQL"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_worker" {
  security_group_id            = aws_security_group.db.id
  description                  = "Worker tasks can reach MySQL"
  referenced_security_group_id = aws_security_group.worker_ecs.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_migration" {
  security_group_id            = aws_security_group.db.id
  description                  = "Temporary migration clients can reach MySQL"
  referenced_security_group_id = aws_security_group.migration.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
