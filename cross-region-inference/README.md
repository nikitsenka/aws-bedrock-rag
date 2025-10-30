# Understand Inference Profiles
## List inference profiles

```bash
aws bedrock list-inference-profiles --query 'inferenceProfileSummaries[?contains(inferenceProfileName, `Sonnet 4.5`)]'
```

## Get inference profile details

```bash
aws bedrock get-inference-profile --inference-profile-identifier us.anthropic.claude-3-haiku-20240307-v1:0
```

## Get quotas

Get all Bedrock quotas for a region:
```bash
aws service-quotas list-service-quotas --service-code bedrock --region us-east-1
```

Get Claude 4.5 cross-region quotas for specific region:
```bash
aws service-quotas list-service-quotas --service-code bedrock --region us-west-2 \
  --query 'Quotas[?contains(QuotaName, `Cross-region`) && (contains(QuotaName, `Sonnet 4.5`))].[QuotaName, Value, Adjustable]' \
  --output table
```

## Request quota increase

First, find the quota code:
```bash
aws service-quotas list-service-quotas --service-code bedrock --region us-west-2 \
  --query 'Quotas[?contains(QuotaName, `Cross-region`) && contains(QuotaName, `Sonnet 4.5`)].{Name:QuotaName, Code:QuotaCode, Value:Value}' \
  --output table
```

Request quota increase for Claude Sonnet 4.5 requests per minute:
```bash
aws service-quotas request-service-quota-increase \
  --service-code bedrock \
  --quota-code L-4A6BFAB1 \
  --desired-value 100 \
  --region us-west-2
```

Request quota increase for Claude Sonnet 4.5 tokens per minute:
```bash
aws service-quotas request-service-quota-increase \
  --service-code bedrock \
  --quota-code L-F4DDD3EB \
  --desired-value 10000000 \
  --region us-west-2
```

Check quota increase request status:
```bash
aws service-quotas list-requested-service-quota-change-history-by-quota \
  --service-code bedrock \
  --quota-code L-4A6BFAB1 \
  --region us-west-2
```