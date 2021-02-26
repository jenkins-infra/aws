
terraform {
  backend "s3" {
    bucket  = "tf-remote-state20210218182205331500000003"
    encrypt = true
    kms_key_id = "32bfc103-dd08-4186-8b93-162146524d42"
    key        = "terraform.tfstate"
    region     = "us-east-1"
  }
}
