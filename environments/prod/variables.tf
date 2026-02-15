variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-prod-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_name_tag" {
  description = "Name tag of the existing VPC"
  type        = string
  default     = "main-vpc"
}

variable "office_security_group_name" {
  description = "Name of the existing security group for office IPs"
  type        = string
  default     = "OfficeIPs"
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for node access"
  type        = string
}

variable "enable_public_access" {
  description = "Enable public access to the EKS cluster API endpoint"
  type        = bool
  default     = false  # Production is private only
}

variable "karpenter_node_instance_types" {
  description = "Instance types for Karpenter controller nodes"
  type        = list(string)
  default     = ["t4g.small"]  # More powerful for production
}

variable "karpenter_node_min_size" {
  description = "Minimum size of Karpenter controller node group"
  type        = number
  default     = 1  # Cost-optimized for assignment/testing
}

variable "karpenter_node_max_size" {
  description = "Maximum size of Karpenter controller node group"
  type        = number
  default     = 2
}

variable "karpenter_node_desired_size" {
  description = "Desired size of Karpenter controller node group"
  type        = number
  default     = 1
}

variable "karpenter_version" {
  description = "Version of Karpenter to install"
  type        = string
  default     = "v0.33.0"
}

variable "karpenter_capacity_types" {
  description = "Capacity types for Karpenter-provisioned nodes"
  type        = list(string)
  default     = ["on-demand"]  # Production uses on-demand for reliability
}

variable "karpenter_instance_families" {
  description = "Instance families for Karpenter nodes (ARM64/Graviton)"
  type        = list(string)
  default     = ["t4g", "c7g", "m7g"]  # More powerful instance families
}

variable "karpenter_cpu_limit" {
  description = "Maximum CPU cores for Karpenter to provision"
  type        = string
  default     = "20"  # Higher limit for production
}

variable "karpenter_memory_limit" {
  description = "Maximum memory for Karpenter to provision"
  type        = string
  default     = "40Gi"  # Higher limit for production
}
