locals {
  public_subnets  = { for k, v in var.subnets_config : k => v if v.public }
  private_subnets = { for k, v in var.subnets_config : k => v if !v.public }

  # Un NAT Gateway por AZ (HA) o solo en la primera AZ publica (modo economico, punto unico de falla)
  nat_gateway_subnets = var.nat_gateway_per_az ? aws_subnet.public : {
    for k, v in aws_subnet.public : k => v if k == sort(keys(aws_subnet.public))[0]
  }
}

resource "aws_vpc" "main" {
  count                = var.enable_network ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.project_name }
}

resource "aws_subnet" "public" {
  for_each          = var.enable_network ? local.public_subnets : {}
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(aws_vpc.main[0].cidr_block, 8, each.value.net_num)
  availability_zone = each.value.az
  # false: nada se lanza directo en estas subredes (ALB y NAT Gateway no dependen de
  # esto, cada uno tiene su propia IP publica/EIP). Ya no hay modulo de EC2 sueltas.
  map_public_ip_on_launch = false
  tags                    = { Name = each.key }
}

resource "aws_default_security_group" "main" {
  count  = var.enable_network ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = { Name = "${var.project_name}-default-sg-locked" }
}

resource "aws_subnet" "private" {
  for_each                = var.enable_network ? local.private_subnets : {}
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(aws_vpc.main[0].cidr_block, 8, each.value.net_num)
  availability_zone       = each.value.az
  map_public_ip_on_launch = false
  tags                    = { Name = each.key }
}

resource "aws_internet_gateway" "main" {
  count  = var.enable_network ? 1 : 0
  vpc_id = aws_vpc.main[0].id
}

resource "aws_eip" "nat" {
  for_each = var.enable_network ? local.nat_gateway_subnets : {}
}

resource "aws_nat_gateway" "main" {
  for_each      = var.enable_network ? local.nat_gateway_subnets : {}
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  depends_on    = [aws_internet_gateway.main]

  tags = { Name = "${var.project_name}-nat-${each.key}" }
}

locals {
  # AZ -> id del NAT Gateway de esa misma AZ (si existe)
  nat_gateway_by_az      = { for k, ng in aws_nat_gateway.main : aws_subnet.public[k].availability_zone => ng.id }
  default_nat_gateway_id = var.enable_network ? values(aws_nat_gateway.main)[0].id : null
}

resource "aws_route_table" "public" {
  count  = var.enable_network ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
}

resource "aws_route_table" "private" {
  for_each = var.enable_network ? aws_subnet.private : {}
  vpc_id   = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    # Usa el NAT Gateway de la misma AZ; si esa AZ no tiene uno propio (modo economico), cae al unico existente
    nat_gateway_id = lookup(local.nat_gateway_by_az, each.value.availability_zone, local.default_nat_gateway_id)
  }

  tags = { Name = "${var.project_name}-private-rt-${each.key}" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
