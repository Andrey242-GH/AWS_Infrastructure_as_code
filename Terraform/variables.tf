variable "aws_region" {
  description = "AWS region in which to create the VPC and subnets."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name tag for the VPC."
  type        = string
  default     = "my-codeCreatedVPC"
}
