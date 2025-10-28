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

variable "embedding_model_dimension" {
  description = "Dimension of the embedding model (Titan Embed v1: 1536, Titan Embed v2: 1024)"
  type        = number
  default     = 1024
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

resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name = "bedrock-kb-${local.resource_suffix}-enc"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource     = ["collection/${local.aoss_collection_name}"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network_policy" {
  name = "bedrock-kb-${local.resource_suffix}-net"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource     = ["collection/${local.aoss_collection_name}"]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "data_policy" {
  name = "bedrock-kb-${local.resource_suffix}-data"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource     = ["collection/${local.aoss_collection_name}"]
          ResourceType = "collection"
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          Resource     = ["index/${local.aoss_collection_name}/*"]
          ResourceType = "index"
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = [
        data.aws_caller_identity.current.arn
      ]
      Description = "Data access policy for Bedrock Knowledge Base"
    }
  ])
}

resource "aws_opensearchserverless_collection" "bedrock_kb_collection" {
  name = local.aoss_collection_name
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption_policy,
    aws_opensearchserverless_security_policy.network_policy,
    aws_opensearchserverless_access_policy.data_policy
  ]
}

resource "aws_iam_policy" "bedrock_aoss_policy" {
  name        = "bedrock-aoss-access-${local.resource_suffix}"
  description = "Policy for Bedrock to access OpenSearch Serverless"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = [
          aws_opensearchserverless_collection.bedrock_kb_collection.arn
        ]
      }
    ]
  })
}

resource "null_resource" "create_aoss_index" {
  depends_on = [aws_opensearchserverless_collection.bedrock_kb_collection]

  provisioner "local-exec" {
    command = <<-EOT
      .venv/bin/python - <<'PYTHON'
import boto3
from requests_aws4auth import AWS4Auth
from opensearchpy import OpenSearch, RequestsHttpConnection

region = "${local.aws_region}"
collection_endpoint = "${aws_opensearchserverless_collection.bedrock_kb_collection.collection_endpoint}"
index_name = "${local.aoss_index_name}"
dimension = ${var.embedding_model_dimension}

session = boto3.Session(region_name=region)
credentials = session.get_credentials()

awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    'aoss',
    session_token=credentials.token
)

host = collection_endpoint.replace('https://', '')

client = OpenSearch(
    hosts=[{'host': host, 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    timeout=300
)

index_body = {
    "settings": {
        "index.knn": "true",
        "number_of_shards": 1,
        "knn.algo_param.ef_search": 512,
        "number_of_replicas": 0
    },
    "mappings": {
        "properties": {
            "vector": {
                "type": "knn_vector",
                "dimension": dimension,
                "method": {
                    "name": "hnsw",
                    "engine": "faiss",
                    "space_type": "l2"
                }
            },
            "text": {
                "type": "text"
            },
            "text-metadata": {
                "type": "text"
            }
        }
    }
}

try:
    if not client.indices.exists(index=index_name):
        response = client.indices.create(index=index_name, body=index_body)
        print(f"Index '{index_name}' created successfully")
    else:
        print(f"Index '{index_name}' already exists")
except Exception as e:
    print(f"Error: {e}")
    exit(1)
PYTHON
    EOT
  }

  triggers = {
    collection_id = aws_opensearchserverless_collection.bedrock_kb_collection.id
    index_name    = local.aoss_index_name
  }
}
