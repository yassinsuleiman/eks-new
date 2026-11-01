data "aws_region" "current" {}

# Only AZs that are usable without opt-in (excludes Local/Wavelength Zones).
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

  lifecycle {
    postcondition {
      condition     = length(self.names) >= var.az_count
      error_message = "az_count is larger than the number of available AZs in this region."
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Private subnets are large (VPC CNI gives every pod a VPC IP): /20 each in a /16,
  # taken from the bottom of the range. Public subnets only hold load balancers
  # (the regional NAT needs none): /24 each in a /16, taken from the last /20 block (index 15),
  # so the two sets can never overlap for az_count <= 4.
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 240 + i)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

## Subnets
resource "aws_subnet" "private" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  cidr_block              = local.private_subnet_cidrs[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${count.index}"

    # Used later by AWS Load Balancer integration
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  cidr_block              = local.public_subnet_cidrs[count.index]

  tags = {
    Name = "${local.name_prefix}-public-${count.index}"

    # Used later by AWS Load Balancer integration
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

## Regional NAT gateway — one gateway for the whole VPC that spans every AZ
## (no public subnet needed). One EIP per AZ keeps egress IPs stable for allow-listing.
resource "aws_eip" "nat" {
  count  = var.az_count
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "nat" {
  vpc_id            = aws_vpc.this.id
  availability_mode = "regional"

  dynamic "availability_zone_address" {
    for_each = local.azs
    content {
      availability_zone = availability_zone_address.value
      allocation_ids    = [aws_eip.nat[availability_zone_address.key].id]
    }
  }

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

## Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# A single private route table is enough: the regional NAT gateway serves every AZ.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

## VPC endpoints — keep AWS API traffic inside the VPC so nodes don't need
## internet access for bootstrap (ec2, ecr, sts) or image pulls (s3).

resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints-sg"
  description = "Allow HTTPS from within the VPC to interface endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  # No egress rules: endpoint ENIs only answer requests, and SGs are stateful,
  # so return traffic is allowed without an egress rule.

  tags = { Name = "${local.name_prefix}-vpc-endpoints-sg" }
}

locals {
  interface_endpoints = toset([
    "ec2",
    "ecr.api",
    "ecr.dkr",
    "sts",
    "eks",
  ])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${local.name_prefix}-endpoint-${each.key}" }
}

# S3 is a gateway endpoint (free, no ENI needed).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${local.name_prefix}-endpoint-s3" }
}
