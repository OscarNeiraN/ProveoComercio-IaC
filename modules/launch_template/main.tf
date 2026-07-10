resource "aws_launch_template" "this" {
  name_prefix = "${var.project_name}-${var.name_prefix}-"

  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = var.security_group_ids

  # User data (script de inicialización)
  user_data = var.user_data_file != null ? base64encode(file(var.user_data_file)) : (var.user_data != null && var.user_data != "" ? base64encode(var.user_data) : null)

  monitoring {
    enabled = var.monitoring
  }

  ebs_optimized = var.ebs_optimized

  instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior

  tags = merge(
    {
      Name      = "${var.project_name}-launch-template"
      Project   = var.project_name
      ManagedBy = "Terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}