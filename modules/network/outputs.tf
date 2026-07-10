output "vpc_id" {
  value = one(aws_vpc.main[*].id)
}

output "subnet_ids" {
  value = merge(
    { for k, v in aws_subnet.public : k => v.id },
    { for k, v in aws_subnet.private : k => v.id }
  )
}

output "public_subnet_ids" {
  value = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  value = { for k, v in aws_subnet.private : k => v.id }
}

output "nat_public_ip" {
  value = one(aws_eip.nat[*].public_ip)
}
