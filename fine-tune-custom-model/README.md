# Fine-Tune Claude-3 Haiku model provided by Amazon Bedrock

## Pre-requisites

### 1. Permissions
* create and delete Amazon IAM roles (IAMFullAccess policy)
* create, update and delete Amazon S3 buckets (AmazonS3FullAccess policy)
* access Amazon Bedrock (AmazonBedrockFullAccess policy)

### 2. Verify Model Availability for Fine-Tuning

**Important:** Claude 3 Haiku fine-tuning is only available in **us-west-2 (Oregon)** region as of 2025.

Check available models for fine-tuning in your region:

```bash
aws bedrock list-foundation-models \
    --region us-west-2 \
    --by-customization-type FINE_TUNING \
    --query 'modelSummaries[?contains(modelId, `haiku`)].{ModelId:modelId,ModelName:modelName,Provider:providerName}' \
    --output table

```

## Usage

### 1. Initialize and Deploy Infrastructure

```bash
terraform init
terraform apply -auto-approve
```

### 2. Prepare Dataset

```bash
.venv/bin/python3 prepare_dataset.py
```

### 3. Upload Datasets to S3

```bash
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
aws s3 cp haiku-fine-tuning-datasets-samsum/train-samsum-1K.jsonl s3://${BUCKET_NAME}/train-samsum-1K.jsonl
aws s3 cp haiku-fine-tuning-datasets-samsum/validation-samsum-100.jsonl s3://${BUCKET_NAME}/validation-samsum-100.jsonl
aws s3 cp haiku-fine-tuning-datasets-samsum/test-samsum-10.jsonl s3://${BUCKET_NAME}/test-samsum-10.jsonl
```
