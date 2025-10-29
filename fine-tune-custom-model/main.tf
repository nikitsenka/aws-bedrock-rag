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
  region = "us-west-2"
}

resource "random_integer" "suffix" {
  min = 100000
  max = 999999
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  aws_region             = data.aws_region.current.name
  resource_suffix        = random_integer.suffix.result
  s3_bucket_name         = "bedrock-haiku-customization-${local.aws_region}-${local.resource_suffix}"
  customization_job_name = "model-finetune-job-${local.resource_suffix}"
  custom_model_name      = "finetuned-model-${local.resource_suffix}"
  base_model_id          = "anthropic.claude-3-haiku-20240307-v1:0:200k"
  base_model_arn         = "arn:aws:bedrock:${local.aws_region}::foundation-model/${local.base_model_id}"
  s3_train_uri           = "s3://${local.s3_bucket_name}/train-samsum-1K.jsonl"
  s3_validation_uri      = "s3://${local.s3_bucket_name}/validation-samsum-100.jsonl"
  s3_output_uri          = "s3://${local.s3_bucket_name}/outputs/output-${local.custom_model_name}"
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

resource "aws_bedrock_custom_model" "haiku_finetuned" {
  custom_model_name     = local.custom_model_name
  job_name              = local.customization_job_name
  base_model_identifier = local.base_model_arn
  role_arn              = aws_iam_role.bedrock_finetuning_role.arn
  customization_type    = "FINE_TUNING"

  hyperparameters = {
    epochCount                = "5"
    batchSize                 = "32"
    learningRateMultiplier    = "1"
    earlyStoppingThreshold    = "0.001"
    earlyStoppingPatience     = "2"
  }

  training_data_config {
    s3_uri = local.s3_train_uri
  }

  validation_data_config {
    validator {
      s3_uri = local.s3_validation_uri
    }
  }

  output_data_config {
    s3_uri = local.s3_output_uri
  }

  depends_on = [
    aws_iam_role_policy_attachment.bedrock_s3_attach
  ]
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

output "customization_job_name" {
  value       = local.customization_job_name
  description = "Name of the fine-tuning job"
}

output "custom_model_name" {
  value       = local.custom_model_name
  description = "Name of the fine-tuned model"
}

output "custom_model_arn" {
  value       = aws_bedrock_custom_model.haiku_finetuned.custom_model_arn
  description = "ARN of the fine-tuned custom model"
}

output "job_arn" {
  value       = aws_bedrock_custom_model.haiku_finetuned.job_arn
  description = "ARN of the fine-tuning job"
}
