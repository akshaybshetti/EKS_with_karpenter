output "karpenter_namespace" {
  description = "Namespace where Karpenter is installed"
  value       = helm_release.karpenter.namespace
}

output "karpenter_release_name" {
  description = "Name of the Karpenter Helm release"
  value       = helm_release.karpenter.name
}

output "karpenter_chart_version" {
  description = "Version of the Karpenter Helm chart"
  value       = helm_release.karpenter.version
}

output "node_class_name" {
  description = "Name of the Karpenter EC2NodeClass"
  value       = "default"
}

output "node_pool_name" {
  description = "Name of the Karpenter NodePool"
  value       = "default"
}
