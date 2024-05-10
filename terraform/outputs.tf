###################
# ECR
###################

output "repository_registry_id" {
  description = "Registry ID"
  value       = module.ecr.repository_registry_id
}

output "repository_url" {
  description = "Repo URL"
  value       = module.ecr.repository_url
}

###################
# EKS
###################

output "cluster_name" {
  description = "Cluster name"
  value       = module.eks.cluster_name
}