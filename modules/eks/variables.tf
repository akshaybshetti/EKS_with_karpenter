variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "office_security_group_id" {
  description = "ID of the security group for office IPs to attach to nodes"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for node access"
  type        = string
}

variable "enable_public_access" {
  description = "Enable public access to the EKS cluster endpoint"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name (dev, pre-prod, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "pre-prod", "prod"], var.environment)
    error_message = "Environment must be one of: dev, pre-prod, prod"
  }
}

variable "karpenter_node_instance_types" {
  description = "List of instance types for Karpenter controller nodes (ARM64/Graviton)"
  type        = list(string)
  default     = ["t4g.medium"]
}

variable "karpenter_node_min_size" {
  description = "Minimum number of nodes in the Karpenter node group"
  type        = number
  default     = 2
}

variable "karpenter_node_max_size" {
  description = "Maximum number of nodes in the Karpenter node group"
  type        = number
  default     = 3
}

variable "karpenter_node_desired_size" {
  description = "Desired number of nodes in the Karpenter node group"
  type        = number
  default     = 2
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
