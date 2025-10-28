Create Knowledge Base and Ingest Documents


# Prerequisites

## 1. Make sure that you have enabled the following model access in Amazon Bedrock Console

List Amazon Titan embedding models

```bash
aws bedrock list-foundation-models --region us-east-1 --by-provider amazon --query "modelSummaries[?contains(modelId, 'titan-embed')].{ModelId:modelId, ModelName:modelName}" --output table
```

## 2. Permissions
* create and delete Amazon IAM roles
* create, update and delete Amazon S3 buckets
* access to Amazon Bedrock
* access to Amazon OpenSearch Serverless

# Deployment

## 1. Initialize and apply Terraform

```bash
terraform init
terraform apply -auto-approve
```

This will create:
- S3 bucket for document storage
- OpenSearch Serverless collection and vector index
- Bedrock Knowledge Base with Titan Embed v2 embeddings
- Data source connected to S3
- Automatic ingestion of documents from S3

## 2. Download and Upload Sample Document to S3

```bash
curl -o 2022-Shareholder-Letter.pdf "https://s2.q4cdn.com/299287126/files/doc_financials/2023/ar/2022-Shareholder-Letter.pdf"
aws s3 cp 2022-Shareholder-Letter.pdf s3://bedrock-kb-us-east-1-468470/2022-Shareholder-Letter.pdf
```

Verify the upload:
```bash
aws s3 ls s3://bedrock-kb-us-east-1-468470/
```

## 3. Trigger manual ingestion (if needed)

```bash
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id <KB_ID> \
  --data-source-id <DATA_SOURCE_ID>
```

# Using the RAG System

## Query the Knowledge Base

Use the Bedrock Agent Runtime to retrieve relevant information and generate answers:

```bash
aws bedrock-agent-runtime retrieve-and-generate \
  --input '{"text":"What is Amazon focus on long-term thinking?"}' \
  --retrieve-and-generate-configuration '{
    "type": "KNOWLEDGE_BASE",
    "knowledgeBaseConfiguration": {
      "knowledgeBaseId": "RYE37GAKRJ",
      "modelArn": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
    }
  }'
```

## Python Example

```python
import boto3

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime', region_name='us-east-1')

response = bedrock_agent_runtime.retrieve_and_generate(
    input={
        'text': 'What is Amazon focus on long-term thinking?'
    },
    retrieveAndGenerateConfiguration={
        'type': 'KNOWLEDGE_BASE',
        'knowledgeBaseConfiguration': {
            'knowledgeBaseId': 'RYE37GAKRJ',
            'modelArn': 'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0'
        }
    }
)

print(response['output']['text'])
```



