###############################################################
# storage.tf — S3 Bucket & SQS Queue
###############################################################

###############################################################
# S3 Bucket — file uploads from Service 1
###############################################################

resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-uploads-${var.aws_region}"
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################
# SQS Queue — messages from Service 2
###############################################################

resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-queue"
  message_retention_seconds  = 86400   # 1 day
  visibility_timeout_seconds = 30
}
