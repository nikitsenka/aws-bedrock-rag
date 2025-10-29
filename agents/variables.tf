variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "agent_runtime_name" {
  description = "Name for the Bedrock AgentCore Runtime"
  type        = string
  default     = "helloWorldAgent"
}

variable "network_mode" {
  description = "Network mode for the agent runtime (PUBLIC or VPC)"
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC"], var.network_mode)
    error_message = "Network mode must be either PUBLIC or VPC"
  }
}
