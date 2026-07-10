locals {
  public_subnets    = { for k, v in var.subnets_config : k => v if v.public }
  private_subnets   = { for k, v in var.subnets_config : k => v if !v.public }
  public_subnet_ids = [for s in aws_subnet.public : s.id]
}

resource "aws_vpc" "main" {
  count                = var.enable_network ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.project_name }
}

resource "aws_subnet" "public" {
  for_each                = var.enable_network ? local.public_subnets : {}
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(aws_vpc.main[0].cidr_block, 8, each.value.net_num)
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags                    = { Name = each.key }
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
  count = var.enable_network ? 1 : 0
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_network ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = local.public_subnet_ids[0]
  depends_on    = [aws_internet_gateway.main]
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
  count  = var.enable_network ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[0].id
}
