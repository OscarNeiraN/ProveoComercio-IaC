data "tls_public_key" "ssh_key" {
  private_key_pem = file(var.private_key_path)
}

resource "aws_key_pair" "ssh_key" {
  key_name   = var.key_name
  public_key = data.tls_public_key.ssh_key.public_key_openssh
}
