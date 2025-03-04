
terraform {
  required_version = ">= 1.11, <1.12"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}
