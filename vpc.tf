data "aws_availability_zones" "available" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.4"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"
  azs  = data.aws_availability_zones.available.names
  private_subnets = [
    "10.0.16.0/20", # 10.0.16.1 -> 10.0.31.254
    "10.0.32.0/20", # 10.0.32.1 -> 10.0.47.254
    "10.0.64.0/20", # 10.0.64.1 -> 10.0.79.254
  ]
  public_subnets = [
    "10.0.0.16/28", # 10.0.0.17 -> 10.0.0.30
    "10.0.0.32/28", # 10.0.0.33 -> 10.0.0.46
    "10.0.0.48/28", # 10.0.0.49 -> 10.0.0.62
  ]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
