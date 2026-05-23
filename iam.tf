###############################################################
# iam.tf — ECS Execution Role + Task Roles (S3 & SQS)
###############################################################

###############################################################
# Shared trust policy for ECS tasks
###############################################################

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

###############################################################
# ECS Task Execution Role
# Allows ECS agent to pull images from ECR and write logs
###############################################################

resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.project_name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

###############################################################
# Task Role — Service 1 (S3 upload)
# Scoped to PutObject on the specific bucket only
###############################################################

resource "aws_iam_role" "task_role_s3" {
  name               = "${var.project_name}-task-role-s3"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

data "aws_iam_policy_document" "task_policy_s3" {
  statement {
    sid     = "AllowS3PutObject"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.uploads.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_policy_s3" {
  name   = "${var.project_name}-task-policy-s3"
  role   = aws_iam_role.task_role_s3.id
  policy = data.aws_iam_policy_document.task_policy_s3.json
}

###############################################################
# Task Role — Service 2 (SQS send)
# Scoped to SendMessage on the specific queue only
###############################################################

resource "aws_iam_role" "task_role_sqs" {
  name               = "${var.project_name}-task-role-sqs"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

data "aws_iam_policy_document" "task_policy_sqs" {
  statement {
    sid     = "AllowSQSSendMessage"
    actions = ["sqs:SendMessage"]
    resources = [
      aws_sqs_queue.main.arn
    ]
  }
}

resource "aws_iam_role_policy" "task_policy_sqs" {
  name   = "${var.project_name}-task-policy-sqs"
  role   = aws_iam_role.task_role_sqs.id
  policy = data.aws_iam_policy_document.task_policy_sqs.json
}
