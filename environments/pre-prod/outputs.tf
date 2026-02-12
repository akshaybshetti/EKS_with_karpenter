output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID used for the cluster"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used for the cluster"
  value       = module.networking.private_subnet_ids
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "karpenter_namespace" {
  description = "Namespace where Karpenter is installed"
  value       = module.karpenter.karpenter_namespace
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN for Karpenter-managed nodes"
  value       = module.eks.karpenter_node_role_arn
}
