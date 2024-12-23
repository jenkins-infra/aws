
terraform {
  required_version = ">= 1.10, <1.11"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}
