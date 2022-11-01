data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"
  azs  = data.aws_availability_zones.available.names
  private_subnets = [
    # first for eks-cluster
    "10.0.16.0/20", # 10.0.16.1 -> 10.0.31.254
    "10.0.32.0/20", # 10.0.32.1 -> 10.0.47.254
    "10.0.64.0/20", # 10.0.64.1 -> 10.0.79.254
    # next for eks-public
    "10.0.80.0/24", # 10.0.80.1 -> 10.0.80.254
    "10.0.81.0/24", # 10.0.81.1 -> 10.0.81.254
    "10.0.82.0/24", # 10.0.82.1 -> 10.0.82.254
  ]
  public_subnets = [
    # first for vpc's Elastic IPs
    "10.0.0.16/28", # 10.0.0.17 -> 10.0.0.30
    "10.0.0.32/28", # 10.0.0.33 -> 10.0.0.46
    "10.0.0.48/28", # 10.0.0.49 -> 10.0.0.62
  ]

  # One NAT gateway per subnet (default)
  # ref. https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest#one-nat-gateway-per-subnet-default
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}
