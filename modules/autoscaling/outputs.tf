output "autoscaling_group_id" {
  value = try(aws_autoscaling_group.app[0].id, "")
}

output "autoscaling_group_arn" {
  value = try(aws_autoscaling_group.app[0].arn, "")
}

output "autoscaling_group_name" {
  value = try(aws_autoscaling_group.app[0].name, "")
}
