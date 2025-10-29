output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.agent_repository.repository_url
}

output "agent_runtime_role_arn" {
  description = "ARN of the IAM role for the agent runtime"
  value       = aws_iam_role.agent_runtime_role.arn
}

output "agent_runtime_name" {
  description = "Name of the agent runtime"
  value       = var.agent_runtime_name
}

output "region" {
  description = "AWS region"
  value       = data.aws_region.current.id
}

