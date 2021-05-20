
terraform {
  required_version = ">= 0.13.6, <0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.42"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.2"
    }
  }
}
