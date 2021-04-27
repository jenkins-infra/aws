variable "region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.19"
  description = "Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
}


variable "linux_worker_ami" {
  type        = string
  default     = "ami-0ad418be69ef09deb"
  description = "AMI ID for the Linux EC2 nodes"
}
