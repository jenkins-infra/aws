resource "aws_kms_key" "eks" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "~> 14.0.0"
  cluster_name = local.cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = "1.19"
  subnets         = module.vpc.private_subnets

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]

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
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 2
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t2.medium"
      additional_userdata           = "echo foo bar"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
      asg_desired_capacity          = 1
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
      userarn  = data.aws_iam_user.eks_charter.arn,
      username = data.aws_iam_user.eks_charter.user_name,
      groups   = ["system:masters"],
    },
  ]
}

data "aws_iam_user" "eks_charter" {
  user_name = "eks_charter"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
