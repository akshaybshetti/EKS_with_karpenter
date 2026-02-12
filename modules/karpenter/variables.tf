variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  type        = string
}

variable "karpenter_version" {
  description = "Version of Karpenter to install"
  type        = string
  default     = "v0.33.0"
}

variable "karpenter_controller_role_arn" {
  description = "ARN of the IAM role for Karpenter controller"
  type        = string
}

variable "karpenter_node_role_name" {
  description = "Name of the IAM role for nodes managed by Karpenter"
  type        = string
}

variable "interruption_queue_name" {
  description = "Name of the SQS queue for interruption handling"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Karpenter nodes"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID for Karpenter nodes"
  type        = string
}

variable "capacity_types" {
  description = "Capacity types for Karpenter nodes (on-demand, spot)"
  type        = list(string)
  default     = ["on-demand"]
}

variable "instance_families" {
  description = "Instance families for Karpenter to use (ARM64/Graviton)"
  type        = list(string)
  default     = ["t4g", "c7g", "m7g"]
}

variable "cpu_limit" {
  description = "Maximum CPU cores for Karpenter to provision"
  type        = string
  default     = "100"
}

variable "memory_limit" {
  description = "Maximum memory for Karpenter to provision"
  type        = string
  default     = "200Gi"
}

variable "node_taints" {
  description = "Taints to apply to Karpenter-provisioned nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
