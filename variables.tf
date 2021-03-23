variable "region" {
  default     = "us-east-2"
  description = "AWS region"
}

variable "kubernetes_version" {
  default     = "1.19"
  description = "Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
}
