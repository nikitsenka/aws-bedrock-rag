# Fine-Tune Claude-3 Haiku model provided by Amazon Bedrock

## Pre-requisites

### 1. Permissions
* create and delete Amazon IAM roles (IAMFullAccess policy)
* create, update and delete Amazon S3 buckets (AmazonS3FullAccess policy)
* access Amazon Bedrock (AmazonBedrockFullAccess policy)

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
