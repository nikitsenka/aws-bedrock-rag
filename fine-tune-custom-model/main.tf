terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_integer" "suffix" {
  min = 100000
  max = 999999
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  aws_region      = data.aws_region.current.name
  resource_suffix = random_integer.suffix.result
  s3_bucket_name  = "bedrock-haiku-customization-${local.aws_region}-${local.resource_suffix}"
}

resource "aws_s3_bucket" "bedrock_haiku_bucket" {
  bucket = local.s3_bucket_name
}

resource "aws_iam_role" "bedrock_finetuning_role" {
  name = "bedrock-haiku-finetuning-role-${local.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${local.aws_region}:${data.aws_caller_identity.current.account_id}:model-customization-job/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_s3_policy" {
  name = "bedrock-haiku-s3-access-${local.resource_suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetBucketAcl",
          "s3:GetBucketNotification",
          "s3:ListBucket",
          "s3:PutBucketNotification"
        ]
        Resource = [
          aws_s3_bucket.bedrock_haiku_bucket.arn,
          "${aws_s3_bucket.bedrock_haiku_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_s3_attach" {
  role       = aws_iam_role.bedrock_finetuning_role.name
  policy_arn = aws_iam_policy.bedrock_s3_policy.arn
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.bedrock_haiku_bucket.id
  description = "S3 bucket name for Claude-3 Haiku fine-tuning data"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.bedrock_haiku_bucket.arn
  description = "S3 bucket ARN for Claude-3 Haiku fine-tuning data"
}

output "finetuning_role_arn" {
  value       = aws_iam_role.bedrock_finetuning_role.arn
  description = "IAM role ARN for Bedrock fine-tuning"
}
