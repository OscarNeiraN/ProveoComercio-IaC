resource "aws_autoscaling_group" "app" {
  count = var.enable_autoscaling ? 1 : 0

  name                = "${var.project_name}-asg"
  max_size            = var.autoscaling_config.max_size
  min_size            = var.autoscaling_config.min_size
  desired_capacity    = var.autoscaling_config.desired_capacity
  vpc_zone_identifier = var.vpc_zone_identifier

  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  target_group_arns = var.target_group_arns

  health_check_type         = var.autoscaling_config.health_check_type
  health_check_grace_period = var.autoscaling_config.health_check_grace_period

  tag {
    key                 = "Name"
    value               = lower("${var.project_name}-asg")
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}
