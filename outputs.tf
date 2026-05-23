###############################################################
# outputs.tf — values needed by the app repo CI/CD pipelines
###############################################################

output "ecr_repo_uri_s3_service" {
  description = "ECR repository URI for the S3 upload service"
  value       = aws_ecr_repository.service_s3.repository_url
}

output "ecr_repo_uri_sqs_service" {
  description = "ECR repository URI for the SQS message service"
  value       = aws_ecr_repository.service_sqs.repository_url
}

output "s3_bucket_name" {
  description = "Name of the S3 uploads bucket"
  value       = aws_s3_bucket.uploads.bucket
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.main.url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name_s3" {
  description = "ECS service name for the S3 upload service"
  value       = aws_ecs_service.service_s3.name
}

output "ecs_service_name_sqs" {
  description = "ECS service name for the SQS message service"
  value       = aws_ecs_service.service_sqs.name
}
