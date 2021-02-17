
terraform {
  backend "s3" {
    bucket     = "tf-remote-state20210215170832448100000002"
    encrypt    = true
    kms_key_id = "317f9474-4f82-4fca-a6c8-777739fa82f9"
    key        = "terraform.tfstate"
    region     = "us-east-1"
  }
}
