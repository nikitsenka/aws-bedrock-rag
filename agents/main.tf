terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.17.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_integer" "suffix" {
  min = 100000
  max = 999999
}

resource "aws_ecr_repository" "agent_repository" {
  name = "bedrock-agentcore-hello-${random_integer.suffix.result}"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true
}

resource "aws_iam_role" "agent_runtime_role" {
  name = "bedrock-agentcore-runtime-${random_integer.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock-agentcore.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "agent_runtime_policy" {
  name = "bedrock-agentcore-runtime-policy"
  role = aws_iam_role.agent_runtime_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.id}::foundation-model/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_bedrockagentcore_agent_runtime" "hello_world_agent" {
  agent_runtime_name = var.agent_runtime_name
  role_arn           = aws_iam_role.agent_runtime_role.arn
  description        = "Hello World LangGraph agent with Claude Sonnet 4.5"

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.agent_repository.repository_url}:latest"
    }
  }

  network_configuration {
    network_mode = var.network_mode
  }

  depends_on = [
    aws_iam_role_policy.agent_runtime_policy
  ]
}
