output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "frontend_ecs_sg_id" {
  value = aws_security_group.frontend_ecs.id
}

output "backend_ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "worker_ecs_sg_id" {
  value = aws_security_group.worker_ecs.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}

output "backend_alb_sg_id" {
  value = aws_security_group.backend_alb.id
}

output "migration_sg_id" {
  value = aws_security_group.migration.id
}
