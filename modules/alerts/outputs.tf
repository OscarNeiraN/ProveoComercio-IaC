output "topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "Topico SNS usado por todas las alarmas de esta infraestructura"
}
