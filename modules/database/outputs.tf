output "db_endpoint" {
  value = one(aws_db_instance.mysql[*].address)
}

output "db_connection_endpoint" {
  value = one(aws_db_instance.mysql[*].endpoint)
}

output "db_port" {
  value = one(aws_db_instance.mysql[*].port)
}

output "db_subnet_group_id" {
  value = one(aws_db_subnet_group.main[*].id)
}
