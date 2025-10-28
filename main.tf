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

variable "embedding_model_id" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

locals {
  aws_region            = data.aws_region.current.name
  resource_suffix       = random_integer.suffix.result
  s3_bucket_name        = "bedrock-kb-${local.aws_region}-${local.resource_suffix}"
  aoss_collection_name  = "bedrock-kb-collection-${local.resource_suffix}"
  aoss_index_name       = "bedrock-kb-index-${local.resource_suffix}"
  bedrock_kb_name       = "bedrock-kb-${local.resource_suffix}"
  embedding_model_arn   = "arn:aws:bedrock:${local.aws_region}::foundation-model/${var.embedding_model_id}"
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
        data.aws_caller_identity.current.arn,
        aws_iam_role.bedrock_kb_role.arn
      ]
      Description = "Data access policy for Bedrock Knowledge Base"
    }
  ])

  depends_on = [aws_iam_role.bedrock_kb_role]
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

resource "aws_iam_role" "bedrock_kb_role" {
  name = "bedrock-kb-role-${local.resource_suffix}"

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
            "aws:SourceArn" = "arn:aws:bedrock:${local.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_kb_model_policy" {
  name = "bedrock-kb-model-${local.resource_suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          local.embedding_model_arn
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_kb_s3_policy" {
  name = "bedrock-kb-s3-${local.resource_suffix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.bedrock_kb_bucket.arn,
          "${aws_s3_bucket.bedrock_kb_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_model_attach" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = aws_iam_policy.bedrock_kb_model_policy.arn
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_s3_attach" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = aws_iam_policy.bedrock_kb_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_aoss_attach" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = aws_iam_policy.bedrock_aoss_policy.arn
}

resource "aws_bedrockagent_knowledge_base" "kb" {
  name     = local.bedrock_kb_name
  role_arn = aws_iam_role.bedrock_kb_role.arn
  description = "Amazon shareholder letter knowledge base."

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.bedrock_kb_collection.arn
      vector_index_name = local.aoss_index_name
      field_mapping {
        vector_field   = "vector"
        text_field     = "text"
        metadata_field = "text-metadata"
      }
    }
  }

  depends_on = [
    null_resource.create_aoss_index,
    aws_iam_role_policy_attachment.bedrock_kb_model_attach,
    aws_iam_role_policy_attachment.bedrock_kb_s3_attach,
    aws_iam_role_policy_attachment.bedrock_kb_aoss_attach
  ]
}

output "knowledge_base_id" {
  value       = aws_bedrockagent_knowledge_base.kb.id
  description = "Bedrock Knowledge Base ID"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.bedrock_kb_bucket.id
  description = "S3 bucket name for documents"
}

output "aoss_collection_id" {
  value       = aws_opensearchserverless_collection.bedrock_kb_collection.id
  description = "OpenSearch Serverless collection ID"
}
