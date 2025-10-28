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

# Usage

## Download and Upload Sample Document to S3

```bash
curl -o 2022-Shareholder-Letter.pdf "https://s2.q4cdn.com/299287126/files/doc_financials/2023/ar/2022-Shareholder-Letter.pdf"
aws s3 cp 2022-Shareholder-Letter.pdf s3://bedrock-kb-us-east-1-468470/2022-Shareholder-Letter.pdf
```

Verify the upload:
```bash
aws s3 ls s3://bedrock-kb-us-east-1-468470/
```


