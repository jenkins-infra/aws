
terraform {
  # Use "terraform init -backend-config=PATH" to setup state in a s3 bucket
  backend "s3" {}
}
