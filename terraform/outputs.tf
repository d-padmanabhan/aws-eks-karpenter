output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.todos.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.todos.arn
}

output "pod_authentication_mode" {
  description = "Pod authentication mode being used"
  value       = var.pod_authentication_mode
}

output "backend_role_arn" {
  description = "IAM role ARN for backend service account (IRSA or Pod Identity)"
  value       = var.pod_authentication_mode == "irsa" ? aws_iam_role.backend_irsa[0].arn : aws_iam_role.backend_pod_identity[0].arn
}

# Deprecated: Use backend_role_arn instead
output "backend_irsa_role_arn" {
  description = "[DEPRECATED] Use backend_role_arn instead. IAM role ARN for backend service account"
  value       = var.pod_authentication_mode == "irsa" ? aws_iam_role.backend_irsa[0].arn : "N/A (using Pod Identity mode)"
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
