output "instance_ids" {
  value       = { for k, v in aws_instance.apps : k => v.id }
  description = "ID de las instancias creadas"
}

output "instance_public_ips" {
  value       = { for k, v in aws_instance.apps : k => v.public_ip }
  description = "Direcciones IP publicas de las instancias"
}