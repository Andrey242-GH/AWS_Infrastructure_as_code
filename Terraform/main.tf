terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  subnets = {
    Public_Subnet_1 = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1a"
    }
    Private_Subnet_1 = {
      cidr_block        = "10.0.10.0/24"
      availability_zone = "us-east-1a"
    }
    Public_Subnet_2 = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "us-east-1b"
    }
  }

  # Only subnets whose name starts with "Public_" get internet access.
  public_subnets = {
    for name, config in local.subnets : name => config
    if strcontains(name, "Public_")
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "subnets" {
  for_each = local.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  # Instances launched into a public subnet automatically receive a public IPv4
  # address. Private subnets do not get this setting — they route outbound
  # traffic through the NAT Gateway instead.
  map_public_ip_on_launch = strcontains(each.key, "Public_")

  tags = {
    Name = each.key
  }
}

# -------------------------
# Internet Gateway
# -------------------------
# Creates the IGW and attaches it to the VPC in a single resource.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-codeCreatedIGW"
  }
}

# -------------------------
# Route Table for public subnets
# -------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # The 0.0.0.0/0 route pointing at the IGW is what makes a subnet "public".
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public_Route_Table"
  }
}

# Associate every public subnet with the public route table.
# for_each iterates only over local.public_subnets (the filtered map),
# so private subnets are automatically excluded — they stay on the
# VPC's default main route table which has no internet route.
resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.public.id
}

# -------------------------
# Elastic IP for NAT Gateway
# -------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "my-codeCreatedNATGW-EIP"
  }
}

# -------------------------
# NAT Gateway (placed in Public_Subnet_1)
# -------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnets["Public_Subnet_1"].id

  tags = {
    Name = "my-codeCreatedNATGW"
  }

  # NAT GW requires the IGW to exist first
  depends_on = [aws_internet_gateway.main]
}

# -------------------------
# Route Table for private subnets
# -------------------------
# Routes outbound traffic from private subnets through the NAT Gateway
# so instances can reach the internet without being directly reachable.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "Private_Route_Table"
  }
}

# Associate every private subnet with the private route table.
locals {
  private_subnets = {
    for name, config in local.subnets : name => config
    if strcontains(name, "Private_")
  }
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.private.id
}
