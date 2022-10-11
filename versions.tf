
terraform {
  required_version = ">= 1.1, <1.2"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    tls = {
      source = "hashicorp/tls"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
