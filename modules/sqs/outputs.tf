output "queue_url" {
  value = aws_sqs_queue.main[0].url
}

output "queue_arn" {
  value = aws_sqs_queue.main[0].arn
}

output "queue_name" {
  value = aws_sqs_queue.main[0].name
}
