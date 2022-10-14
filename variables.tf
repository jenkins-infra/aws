variable "region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region"
}

# Needed for https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest#one-nat-gateway-per-availability-zone
variable "azs" {
  description = "A list of Availability zones in the region"
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "kubernetes_version" {
  type        = string
  default     = "1.22"
  description = "Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
}
