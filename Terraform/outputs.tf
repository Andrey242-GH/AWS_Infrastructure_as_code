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

output "bastion_instance_id" {
  description = "Instance ID of the bastion host in Public_Subnet_1."
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "private_instance_ids" {
  description = "Instance IDs of the two private HeartBeat instances."
  value       = aws_instance.private[*].id
}

output "private_instance_public_ips" {
  description = "Public IP addresses of the private HeartBeat instances."
  value       = aws_instance.private[*].public_ip
}

output "private_instance_private_ips" {
  description = "Private IP addresses of the private HeartBeat instances (use these from inside the VPC)."
  value       = aws_instance.private[*].private_ip
}

output "security_group_id" {
  description = "ID of the ec2_HeartBeat security group."
  value       = aws_security_group.ec2_heartbeat.id
}
