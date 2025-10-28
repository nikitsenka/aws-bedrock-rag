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
  region = "us-east-1"  # You can change this to your preferred region
}

# Generate random suffix for resource names
resource "random_integer" "suffix" {
  min = 100000
  max = 999999
}

locals {
  aws_region            = data.aws_region.current.name
  resource_suffix       = random_integer.suffix.result
  s3_bucket_name        = "bedrock-kb-${local.aws_region}-${local.resource_suffix}"
  aoss_collection_name  = "bedrock-kb-collection-${local.resource_suffix}"
  aoss_index_name       = "bedrock-kb-index-${local.resource_suffix}"
  bedrock_kb_name       = "bedrock-kb-${local.resource_suffix}"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "bedrock_kb_bucket" {
  bucket = local.s3_bucket_name
}
