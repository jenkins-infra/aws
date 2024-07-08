provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = local.common_tags
  }
}

provider "local" {
}
