# Data source to fetch existing VPC by tags
data "aws_vpc" "main" {
  tags = {
    Name = var.vpc_name_tag
  }
}

# Data source to fetch private subnets by tags
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "private"
  }
}

# Fetch subnet details for availability zone distribution
data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}

# Data source to fetch existing security group for office IPs
data "aws_security_group" "office_ips" {
  name   = var.office_security_group_name
  vpc_id = data.aws_vpc.main.id
}

# Data source to fetch existing SSH key pair
data "aws_key_pair" "ssh_key" {
  key_name = var.ssh_key_name
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
