output "alb_dns_name" {
  value = aws_lb.app[0].dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.app[0].arn_suffix
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend[0].arn
}

output "frontend_target_group_arn_suffix" {
  value = aws_lb_target_group.frontend[0].arn_suffix
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend[0].arn
}

output "backend_target_group_arn_suffix" {
  value = aws_lb_target_group.backend[0].arn_suffix
}

output "backend_alb_arn_suffix" {
  value = aws_lb.backend[0].arn_suffix
}

output "backend_internal_dns_name" {
  value = aws_lb.backend[0].dns_name
}
