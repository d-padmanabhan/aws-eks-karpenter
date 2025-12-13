variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "todo-app-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "pod_authentication_mode" {
  description = "Pod authentication mode: 'irsa' for IAM Roles for Service Accounts or 'pod-identity' for EKS Pod Identity"
  type        = string
  default     = "irsa"

  validation {
    condition     = contains(["irsa", "pod-identity"], var.pod_authentication_mode)
    error_message = "pod_authentication_mode must be either 'irsa' or 'pod-identity'."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "todo-app-table"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}
