output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Where EKS worker nodes go"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Where RDS goes"
  value       = aws_subnet.database[*].id
}

output "private_subnet_cidrs" {
  description = "Used later to scope the database security group to the app tier"
  value       = aws_subnet.private[*].cidr_block
}
