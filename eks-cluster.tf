# Define a KMS main key to encrypt the EKS cluster
resource "aws_kms_key" "eks" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true
}

# EKS Cluster definition
module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "18.3.0"
  cluster_name = local.cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = var.kubernetes_version
  subnets         = module.vpc.private_subnets
  # Required to allow EKS service accounts to authenticate to AWS API through OIDC (and assume IAM roles)
  # useful for autoscaler, EKS addons and any AWS APi usage
  enable_irsa = true

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]

  # Do not persist kube config to a local file (if run by a human that would break their configuration)
  write_kubeconfig = false

  tags = {
    Environment = "jenkins-infra-${terraform.workspace}"
    GithubRepo  = "aws"
    GithubOrg   = "jenkins-infra"
  }

  # VPC is defined in vpc.tf
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

  map_users = [
    # User impersonated when using the CloudBees IAM Accounts (e.g. humans)
    {
      userarn  = "arn:aws:iam::200564066411:role/infra-admin",
      username = "infra-admin",
      groups   = ["system:masters"],
    },
    # User defined in the Infra.CI system to operate terraform
    {
      userarn  = "arn:aws:iam::200564066411:user/production-terraform",
      username = "production-terraform",
      groups   = ["system:masters"],
    },
    # User for administrating the charts from github.com/jenkins-infra/charts
    {
      userarn  = data.aws_iam_user.eks_charter.arn,
      username = data.aws_iam_user.eks_charter.user_name,
      groups   = ["system:masters"],
    },
  ]
}

# Reference the existing user for administrating the charts from github.com/jenkins-infra/charts
data "aws_iam_user" "eks_charter" {
  user_name = "eks_charter"
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
