output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value = {
    for name, subnet in aws_subnet.subnets : name => subnet.id
  }
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway."
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_eip" {
  description = "Public Elastic IP address allocated to the NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "private_route_table_id" {
  description = "ID of the private route table (routes via NAT Gateway)."
  value       = aws_route_table.private.id
}
