# ==============================================================================
# VPC Creation (Conditional)
# ==============================================================================

resource "aws_vpc" "eks" {
  count = var.vpc_create ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-vpc"
    }
  )
}

# ==============================================================================
# Public Subnets
# ==============================================================================

resource "aws_subnet" "public" {
  count = var.vpc_create ? var.availability_zone_count : 0

  vpc_id                  = aws_vpc.eks[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 100)
  availability_zone       = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                                          = "${local.naming_prefix}-public-${count.index}"
      "kubernetes.io/role/elb"                      = "1"
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    }
  )
}

# ==============================================================================
# Private Subnets (Optional)
# ==============================================================================

resource "aws_subnet" "private" {
  count = var.vpc_create && var.create_private_subnets ? var.availability_zone_count : 0

  vpc_id            = aws_vpc.eks[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available[0].names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name                                          = "${local.naming_prefix}-private-${count.index}"
      "kubernetes.io/role/internal-elb"             = "1"
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    }
  )
}

# ==============================================================================
# Internet Gateway
# ==============================================================================

resource "aws_internet_gateway" "eks" {
  count = var.vpc_create ? 1 : 0

  vpc_id = aws_vpc.eks[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-igw"
    }
  )
}

# ==============================================================================
# NAT Gateway (Optional)
# ==============================================================================

resource "aws_eip" "nat" {
  count = var.vpc_create && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.availability_zone_count) : 0

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-nat-eip-${count.index}"
    }
  )

  depends_on = [aws_internet_gateway.eks]
}

resource "aws_nat_gateway" "eks" {
  count = var.vpc_create && var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.availability_zone_count) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-nat-${count.index}"
    }
  )

  depends_on = [aws_internet_gateway.eks]
}

# ==============================================================================
# Public Route Table
# ==============================================================================

resource "aws_route_table" "public" {
  count = var.vpc_create ? 1 : 0

  vpc_id = aws_vpc.eks[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks[0].id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  count = var.vpc_create ? var.availability_zone_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ==============================================================================
# Private Route Table (Optional)
# ==============================================================================

resource "aws_route_table" "private" {
  count = var.vpc_create && var.create_private_subnets ? var.availability_zone_count : 0

  vpc_id = aws_vpc.eks[0].id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.eks[0].id : aws_nat_gateway.eks[count.index].id
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.naming_prefix}-private-rt-${count.index}"
    }
  )
}

resource "aws_route_table_association" "private" {
  count = var.vpc_create && var.create_private_subnets ? var.availability_zone_count : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
