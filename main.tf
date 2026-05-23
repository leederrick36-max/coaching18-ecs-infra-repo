###############################################################
# main.tf — ECS Cluster, ECR Repositories, ECS Task Definitions & Services
###############################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend — replace bucket/table with your own
  backend "s3" {
    bucket         = "coaching18-ecs-infra"
    key            = "ecs-infra/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

###############################################################
# Data sources — reuse the default VPC & subnets
###############################################################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

###############################################################
# ECR Repositories
###############################################################

resource "aws_ecr_repository" "service_s3" {
  name                 = "${var.project_name}-service-s3"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "service_sqs" {
  name                 = "${var.project_name}-service-sqs"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

###############################################################
# ECS Cluster
###############################################################

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

###############################################################
# CloudWatch Log Groups
###############################################################

resource "aws_cloudwatch_log_group" "service_s3" {
  name              = "/ecs/${var.project_name}/service-s3"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "service_sqs" {
  name              = "/ecs/${var.project_name}/service-sqs"
  retention_in_days = 7
}

###############################################################
# ECS Task Definitions
###############################################################

resource "aws_ecs_task_definition" "service_s3" {
  family                   = "${var.project_name}-service-s3"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.task_role_s3.arn

  container_definitions = jsonencode([
    {
      name      = "service-s3"
      image     = "${aws_ecr_repository.service_s3.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "BUCKET_NAME"
          value = aws_s3_bucket.uploads.bucket
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_s3.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "service_sqs" {
  family                   = "${var.project_name}-service-sqs"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.task_role_sqs.arn

  container_definitions = jsonencode([
    {
      name      = "service-sqs"
      image     = "${aws_ecr_repository.service_sqs.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5002
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "QUEUE_URL"
          value = aws_sqs_queue.main.url
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_sqs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

###############################################################
# Security Group — allow inbound on container ports
###############################################################

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow inbound traffic to ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################
# ECS Services
###############################################################

resource "aws_ecs_service" "service_s3" {
  name            = "${var.project_name}-service-s3"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_s3.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  # Allows pipeline to update image without Terraform drift
  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "service_sqs" {
  name            = "${var.project_name}-service-sqs"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_sqs.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}
