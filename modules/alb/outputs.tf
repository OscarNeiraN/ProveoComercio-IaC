output "alb_dns_name" {
  value = aws_lb.app[0].dns_name
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend[0].arn
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend[0].arn
}

output "backend_internal_dns_name" {
  value = aws_lb.backend[0].dns_name
}
