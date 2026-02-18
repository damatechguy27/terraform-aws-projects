resource "aws_vpc" "eks" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# resource "aws_subnet" "private" {
#   count             = 2
#   vpc_id            = aws_vpc.eks.id
#   cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
#   availability_zone = data.aws_availability_zones.available.names[count.index]

#   tags = {
#     Name                                        = "${var.cluster_name}-private-${count.index}"
#     "kubernetes.io/role/internal-elb"            = "1"
#     "kubernetes.io/cluster/${var.cluster_name}"  = "owned"
#   }
# }

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 100)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "owned"
  }
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id
  tags   = { Name = "${var.cluster_name}-igw" }
}

# resource "aws_eip" "nat" {
#   domain = "vpc"
#   tags   = { Name = "${var.cluster_name}-nat-eip" }
# }

# resource "aws_nat_gateway" "eks" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public[0].id
#   tags          = { Name = "${var.cluster_name}-nat" }

#   depends_on = [aws_internet_gateway.eks]
# }

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }
  tags = { Name = "${var.cluster_name}-public-rt" }
}

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.eks.id
#   route {
#     cidr_block     = "0.0.0.0/0"
# //    nat_gateway_id = aws_nat_gateway.eks.id
#   }
#   tags = { Name = "${var.cluster_name}-private-rt" }
# }

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# resource "aws_route_table_association" "private" {
#   count          = 2
#   subnet_id      = aws_subnet.private[count.index].id
#   route_table_id = aws_route_table.private.id
# }
