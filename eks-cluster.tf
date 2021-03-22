module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "~> 14.0.0"
  cluster_name = local.cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = var.kubernetes_version
  subnets         = module.vpc.private_subnets

  # Do not create a local file
  write_kubeconfig = false

  tags = {
    Environment = "jenkins-infra-${terraform.workspace}"
    GithubRepo  = "aws"
    GithubOrg   = "jenkins-infra"
  }

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                 = "main"
      instance_type        = "m5a.2xlarge"
      asg_desired_capacity = 2
      asg_min_size         = 2
      asg_max_size         = 5
      public_ip            = false
      kubelet_extra_args   = "--node-labels=node.kubernetes.io/lifecycle=normal"
      suspended_processes  = ["AZRebalance"]
    },
    {
      name                = "peak"
      instance_type       = "m5a.2xlarge"
      spot_price          = "0.344" # https://aws.amazon.com/ec2/pricing/on-demand/
      asg_max_size        = 5
      public_ip           = false
      kubelet_extra_args  = "--node-labels=node.kubernetes.io/lifecycle=spot"
      suspended_processes = ["AZRebalance"]
    },
  ]

  # This block is a temporary fix for https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1205
  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  map_users = [
    // User impersonnated when using the CloudBees IAM Accounts (e.g. humans)
    {
      userarn  = "arn:aws:sts::200564066411:assumed-role/infra-admin/tba",
      username = "infra-admin",
      groups   = ["system:masters"],
    },
    // User defined in the Infra.CI system
    {
      userarn  = "arn:aws:iam::200564066411:user/production-terraform",
      username = "production-terraform",
      groups   = ["system:masters"],
    },
    // User for administrating the charts from github.com/jenkins-infra/charts
    {
      userarn  = aws_iam_user.eks_charter.arn,
      username = aws_iam_user.eks_charter.name,
      groups   = ["system:masters"],
    },
  ]
}

resource "aws_iam_user" "eks_charter" {
  name = "eks_charter"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
