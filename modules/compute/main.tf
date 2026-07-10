resource "aws_instance" "apps" {
  for_each               = var.enable_compute ? var.instances_config : {}
  ami                    = var.ami_id
  instance_type          = each.value.type
  subnet_id              = var.subnet_map_ids[each.value.subnet_key]
  vpc_security_group_ids = var.vpc_security_group_ids
  key_name               = var.key_name

  tags = {
    Name = lower("${each.key}-${var.project_name}")
  }
}