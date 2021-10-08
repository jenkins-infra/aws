resource "aws_kms_key" "eks" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "~> 17.20"
  cluster_name = local.cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = var.kubernetes_version
  subnets         = module.vpc.private_subnets
  enable_irsa     = true

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
      name                 = "main-linux"
      instance_type        = "m5a.4xlarge"
      asg_desired_capacity = 1 # This value will be changed extrnally by the autoscaler helm chart, so we set it to the bare minimum here.
      asg_min_size         = 1
      asg_max_size         = 50
      public_ip            = false
      kubelet_extra_args   = "--node-labels=node.kubernetes.io/lifecycle=normal"
      suspended_processes  = ["AZRebalance"]
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "propagate_at_launch" = "false"
          "value"               = "true"
        },
        {
          "key"                 = "k8s.io/cluster-autoscaler/${local.cluster_name}"
          "propagate_at_launch" = "false"
          "value"               = "owned"
        }
      ]
    },
    # TODO: to be added later as the autoscaling pool for peak activity while "main-linux" pool should be almost static
    # {
    #   name                = "peak"
    #   instance_type       = "t3a.2xlarge"
    #   spot_price          = "0.300" # https://aws.amazon.com/ec2/pricing/on-demand/
    #   asg_max_size        = 5
    #   public_ip           = false
    #   kubelet_extra_args  = "--node-labels=node.kubernetes.io/lifecycle=spot"
    #   suspended_processes = ["AZRebalance"]
    # },
  ]

  # This block is a temporary fix for https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1205
  workers_group_defaults = {
    root_volume_type = "gp2"
    ami_id           = var.linux_worker_ami
  }

  map_users = [
    // User impersonnated when using the CloudBees IAM Accounts (e.g. humans)
    {
      userarn  = "arn:aws:iam::200564066411:role/infra-admin",
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
