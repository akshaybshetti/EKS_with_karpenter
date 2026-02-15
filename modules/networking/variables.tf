variable "vpc_name_tag" {
  description = "Name tag of the existing VPC to use"
  type        = string
  default     = "main-vpc" // Update this default value as needed
}

variable "office_security_group_name" {
  description = "Name of the existing security group for office IPs"
  type        = string
  default     = "OfficeIPs"
}

variable "ssh_key_name" {
  description = "Name of the existing SSH key pair for EC2 instances"
  type        = string
}
