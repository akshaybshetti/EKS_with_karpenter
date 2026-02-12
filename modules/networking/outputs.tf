output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = data.aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = data.aws_subnets.private.ids
}

output "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks of private subnets"
  value       = [for s in data.aws_subnet.private : s.cidr_block]
}

output "availability_zones" {
  description = "List of availability zones used by private subnets"
  value       = [for s in data.aws_subnet.private : s.availability_zone]
}

output "office_security_group_id" {
  description = "ID of the office IPs security group"
  value       = data.aws_security_group.office_ips.id
}

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = data.aws_key_pair.ssh_key.key_name
}
