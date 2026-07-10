resource "aws_lb" "app" {
  count                      = var.enable_alb ? 1 : 0
  name                       = var.alb_config.name
  load_balancer_type         = "application"
  internal                   = var.alb_config.internal
  security_groups            = var.security_group_ids
  subnets                    = var.subnet_ids
  enable_deletion_protection = false
  drop_invalid_header_fields = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "frontend" {
  count       = var.enable_alb ? 1 : 0
  name        = "${var.project_name}-frontend-tg"
  port        = var.alb_config.frontend_port
  protocol    = var.alb_config.target_protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = var.alb_config.target_protocol
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "backend" {
  count                      = var.enable_alb ? 1 : 0
  name                       = "${var.project_name}-backend-alb"
  load_balancer_type         = "application"
  internal                   = true
  security_groups            = var.backend_security_group_ids
  subnets                    = var.backend_subnet_ids
  enable_deletion_protection = false
  drop_invalid_header_fields = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "backend" {
  count       = var.enable_alb ? 1 : 0
  name        = "${var.project_name}-backend-tg"
  port        = var.alb_config.backend_port
  protocol    = var.alb_config.target_protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = var.alb_config.target_protocol
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "backend_http" {
  count             = var.enable_alb ? 1 : 0
  load_balancer_arn = aws_lb.backend[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }
}

resource "aws_lb_listener" "http" {
  count             = var.enable_alb ? 1 : 0
  load_balancer_arn = aws_lb.app[0].arn
  port              = var.alb_config.listener_port
  protocol          = var.alb_config.protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[0].arn
  }
  lifecycle {
    create_before_destroy = true
  }
}
