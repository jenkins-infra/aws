data "aws_availability_zones" "available" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.3"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"
  azs  = data.aws_availability_zones.available.names
  private_subnets = [
    "10.0.16.0/20", # 10.0.16.1 -> 10.0.31.254 (4096 hosts)
    "10.0.32.0/20", # 10.0.32.1 -> 10.0.47.254 (4096 hosts)
    "10.0.64.0/20", # 10.0.64.1 -> 10.0.79.254 (4096 hosts)
  ]
  public_subnets = [
    "10.0.0.0/29",  # 10.0.0.1 -> 10.0.0.7 (6 hosts + broadcast)
    "10.0.0.8/29",  # 10.0.0.9 -> 10.0.0.15 (6 hosts + broadcast)
    "10.0.0.16/29", # 10.0.0.17 -> 10.0.0.22 (6 hosts + broadcast)
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
