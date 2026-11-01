output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability Zones used, in subnet order"
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of all public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of all private subnets"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "ID of the shared public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the shared private route table"
  value       = aws_route_table.private.id
}

output "nat_gateway_id" {
  description = "ID of the regional NAT gateway"
  value       = aws_nat_gateway.nat.id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways (egress IPs for allow-listing)"
  value       = aws_eip.nat[*].public_ip
}
