output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "internet_gateway_id" { value = aws_internet_gateway.main.id }
output "nat_gateway_id" { value = try(aws_nat_gateway.main[0].id, null) }

output "public_subnet_auto_ipv4" { value = aws_subnet.public[*].map_public_ip_on_launch }
