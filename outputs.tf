output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = values(module.network.public_subnet_ids)
}

output "private_subnet_ids" {
  value = values(module.network.private_subnet_ids)
}

output "nat_public_ip" {
  value       = module.network.nat_public_ip
  description = "IP publica de salida para tareas privadas via NAT Gateway"
}

output "migration_sg_id" {
  value       = module.security.migration_sg_id
  description = "SG temporal para clientes de migracion dentro de la VPC"
}

output "public_alb_sg_id" {
  value       = module.security.alb_sg_id
  description = "SG del ALB publico; acepta HTTP desde Internet"
}

output "backend_alb_sg_id" {
  value       = module.security.backend_alb_sg_id
  description = "SG del ALB interno; acepta HTTP solo desde el frontend"
}

output "frontend_ecs_sg_id" {
  value       = module.security.frontend_ecs_sg_id
  description = "SG usado por las tareas frontend; acepta trafico solo desde el ALB publico"
}

output "backend_ecs_sg_id" {
  value       = module.security.backend_ecs_sg_id
  description = "SG usado por las tareas backend; acepta trafico solo desde el ALB interno"
}

output "worker_ecs_sg_id" {
  value       = module.security.worker_ecs_sg_id
  description = "SG usado por las tareas worker; no tiene inbound"
}

output "backend_internal_alb_dns_name" {
  value       = module.alb.backend_internal_dns_name
  description = "DNS privado del ALB interno del backend"
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS del balanceador de carga"
}

output "frontend_url" {
  value       = "http://${module.alb.alb_dns_name}"
  description = "URL publica del frontend"
}

output "db_endpoint" {
  value       = module.database.db_endpoint
  description = "Hostname privado del RDS MySQL"
}

output "db_connection_endpoint" {
  value       = module.database.db_connection_endpoint
  description = "Endpoint privado completo del RDS MySQL, con puerto"
}

output "db_port" {
  value = module.database.db_port
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "sqs_queue_name" {
  value = module.sqs.queue_name
}

output "frontend_ecr_repository_url" {
  value       = module.ecr.frontend_repo_url
  description = "Repositorio ECR para la imagen del frontend"
}

output "backend_ecr_repository_url" {
  value       = module.ecr.backend_repo_url
  description = "Repositorio ECR para la imagen del backend"
}

output "db_migrator_ecr_repository_url" {
  value       = module.ecr.db_migrator_repo_url
  description = "Repositorio ECR para la imagen temporal de migracion MySQL"
}

output "migration_cluster_name" {
  value       = module.migration.cluster_name
  description = "Cluster ECS temporal para importar dump MySQL"
}

output "migration_task_definition_arn" {
  value       = module.migration.task_definition_arn
  description = "Task definition Fargate para importar dump MySQL"
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "frontend_service_name" {
  value = module.ecs.frontend_service_name
}

output "backend_service_name" {
  value = module.ecs.backend_service_name
}

output "worker_service_name" {
  value = module.ecs.worker_service_name
}

output "backend_internal_dns_name" {
  value       = module.ecs.backend_internal_dns_name
  description = "Upstream privado usado por el frontend para llegar al backend"
}
