variable "region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.22"
  description = "Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
}

variable "cluster_name" {
  type        = string
  default     = ""
}
