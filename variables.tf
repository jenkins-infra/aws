variable "region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.21"
  description = "Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
}
