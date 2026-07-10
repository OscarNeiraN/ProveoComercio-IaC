output "key_name" {
  value = aws_key_pair.ssh_key.key_name
}

output "key_pair_id" {
  value = aws_key_pair.ssh_key.id
}
