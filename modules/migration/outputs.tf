output "cluster_name" {
  value = aws_ecs_cluster.migration.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.db_migrator.arn
}
