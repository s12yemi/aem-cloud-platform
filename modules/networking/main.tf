data "aws_region" "current" {}

locals {
  prefix = "${var.name}-${var.environment}"
  azs    = { for index, az in var.availability_zones : tostring(index) => az }
  common_tags = merge(var.tags, {
    Project     = var.name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "${local.prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${local.prefix}-igw" })
}

# A /16 VPC is partitioned into /24s (newbits=8). Indices 0/1, 10/11, 20/21
# keep public, application, and database networks separate.
resource "aws_subnet" "public" {
  for_each                = local.azs
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, tonumber(each.key))
  availability_zone       = each.value
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, {
    Name = "${local.prefix}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "app" {
  for_each                = local.azs
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 10 + tonumber(each.key))
  availability_zone       = each.value
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, {
    Name = "${local.prefix}-app-${each.key}"
    Tier = "private-app"
  })
}

resource "aws_subnet" "database" {
  for_each                = local.azs
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 20 + tonumber(each.key))
  availability_zone       = each.value
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, {
    Name = "${local.prefix}-database-${each.key}"
    Tier = "isolated-database"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.common_tags, { Name = "${local.prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  for_each       = local.azs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = var.nat_mode == "none" ? {} : (var.nat_mode == "single" ? { "0" = var.availability_zones[0] } : local.azs)
  domain   = "vpc"
  tags     = merge(local.common_tags, { Name = "${local.prefix}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each      = aws_eip.nat
  subnet_id     = aws_subnet.public[each.key].id
  allocation_id = each.value.id
  depends_on    = [aws_internet_gateway.this]
  tags          = merge(local.common_tags, { Name = "${local.prefix}-nat-${each.key}" })
}

resource "aws_route_table" "app" {
  for_each = local.azs
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.common_tags, { Name = "${local.prefix}-app-rt-${each.key}" })
}

resource "aws_route" "app_nat" {
  for_each               = var.nat_mode == "none" ? {} : local.azs
  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.nat_mode == "single" ? "0" : each.key].id
}

resource "aws_route_table_association" "app" {
  for_each       = local.azs
  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

# Database subnets intentionally have no default route to the internet.
resource "aws_route_table" "database" {
  for_each = local.azs
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.common_tags, { Name = "${local.prefix}-db-rt-${each.key}" })
}

resource "aws_route_table_association" "database" {
  for_each       = local.azs
  subnet_id      = aws_subnet.database[each.key].id
  route_table_id = aws_route_table.database[each.key].id
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_s3_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.app : rt.id]
  tags              = merge(local.common_tags, { Name = "${local.prefix}-s3-gateway" })
}
