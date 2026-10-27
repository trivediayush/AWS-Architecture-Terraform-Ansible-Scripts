output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "database_subnet_ids" { value = aws_subnet.database[*].id }
output "availability_zones" { value = var.availability_zones }
output "nat_gateway_ids" { value = aws_nat_gateway.this[*].id }
