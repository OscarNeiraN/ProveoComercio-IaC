resource "aws_sqs_queue" "dlq" {
  count                   = var.enable_sqs ? 1 : 0
  name                    = "${var.project_name}-dlq"
  sqs_managed_sse_enabled = true

  message_retention_seconds = var.message_retention_seconds

  tags = {
    Name = "${var.project_name}-dlq"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_sqs_queue" "main" {
  count                   = var.enable_sqs ? 1 : 0
  name                    = "${var.project_name}-queue"
  sqs_managed_sse_enabled = true

  delay_seconds              = var.delay_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name = "${var.project_name}-queue"
  }

  lifecycle {
    prevent_destroy = true
  }
}
