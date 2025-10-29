# Hello World Agent with Amazon Bedrock AgentCore

This project demonstrates deploying a simple LangGraph agent using Claude Sonnet 4.5 to Amazon Bedrock AgentCore Runtime
via Terraform.

## Pre-requisites
### 1. Permissions
* create and delete Bedrock AgentCore runtime (BedrockAgentCoreFullAccess)

## Deployment with Terraform

### Step 1: Initialize Terraform and Create Infrastructure

```bash
terraform init
terraform apply -auto-approve
```

This creates:

- ECR repository for the agent container
- IAM role with Bedrock permissions

### Step 2: Build and Push Docker Image

Get the ECR repository URL from Terraform output:

```bash
export ECR_REPO=$(terraform output -raw ecr_repository_url)
export AWS_REGION=$(terraform output -raw region)
```

Login to ECR:

```bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
```

Build and push the Docker image (ARM64 architecture required):

```bash
docker build --platform linux/arm64 -t $ECR_REPO:latest .
docker push $ECR_REPO:latest
```
