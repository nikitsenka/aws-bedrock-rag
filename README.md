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


