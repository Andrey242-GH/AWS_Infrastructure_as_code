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

  tags = {
    Name = each.key
  }
}
