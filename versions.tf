
terraform {
  required_version = ">= 0.13.6, <1.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.53"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.4"
    }
  }
}
