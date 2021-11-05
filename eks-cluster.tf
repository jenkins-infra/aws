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
      # This worker pool is expected to host the "technical" services such as pod autoscaler, etc.
      name                = "tiny-ondemand-linux"
      instance_type       = "t3a.xlarge"
      asg_max_size        = 2
      public_ip           = false
      kubelet_extra_args  = "--node-labels=node.kubernetes.io/lifecycle=normal"
      suspended_processes = ["AZRebalance"]
      tags = [
        {
          "key"                 = "k8s.io/cluster-autoscaler/enabled"
          "propagate_at_launch" = "false"
          "value"               = "false" # No autoscaling for these 2 machines
        },
      ]
    },
  ]

  # This list of worker pool is aimed at mixed spot instances type, to ensure that we always get the most available (e.g. the cheaper) spot size
  # as per https://aws.amazon.com/blogs/compute/cost-optimization-and-resilience-eks-with-spot-instances/
  worker_groups_launch_template = [
    {
      name = "spot-linux-4xlarge"
      # Instances of 16 vCPUs /	64 Gb each
      override_instance_types = ["m5.4xlarge", "m5d.4xlarge", "m5a.4xlarge", "m5ad.4xlarge", "m5n.4xlarge", "m5dn.4xlarge"]
      spot_instance_pools     = 6 # Amount of different instance that we can use
      asg_max_size            = 20
      public_ip               = false
      kubelet_extra_args      = "--node-labels=node.kubernetes.io/lifecycle=spot"
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
    // User defined in the Infra.CI system to operate terraform
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
