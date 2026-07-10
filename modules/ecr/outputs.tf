output "frontend_repo_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_repo_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "db_migrator_repo_url" {
  value = aws_ecr_repository.db_migrator.repository_url
}
