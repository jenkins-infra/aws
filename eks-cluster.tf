# Define a KMS main key to encrypt the EKS cluster
resource "aws_kms_key" "eks" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true
}

# EKS Cluster definition
module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "18.6.0"
  cluster_name = local.cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = var.kubernetes_version
  subnet_ids      = module.vpc.private_subnets
  # Required to allow EKS service accounts to authenticate to AWS API through OIDC (and assume IAM roles)
  # useful for autoscaler, EKS addons and any AWS APi usage
  enable_irsa = true

  cluster_encryption_config = [
    {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }
  ]

  tags = {
    Environment = "jenkins-infra-${terraform.workspace}"
    GithubRepo  = "aws"
    GithubOrg   = "jenkins-infra"
  }

  # VPC is defined in vpc.tf
  vpc_id = module.vpc.vpc_id

  self_managed_node_groups = {
    tiny_ondemand_linux = {
      # This worker pool is expected to host the "technical" services such as pod autoscaler, etc.
      name                 = "tiny-ondemand-linux"
      instance_type        = "t3a.xlarge"
      min_size             = 1
      max_size             = 2
      desired_size         = 1
      public_ip            = false
      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'"
      suspended_processes  = ["AZRebalance"]
      tags = {
        "k8s.io/cluster-autoscaler/enabled" = false # No autoscaling for these 2 machines
      },
    },
    # This list of worker pool is aimed at mixed spot instances type, to ensure that we always get the most available (e.g. the cheaper) spot size
    # as per https://aws.amazon.com/blogs/compute/cost-optimization-and-resilience-eks-with-spot-instances/
    spot_linux_4xlarge = {
      name = "spot-linux-4xlarge"
      # Instances of 16 vCPUs /	64 Gb each
      override_instance_types = ["m5.4xlarge", "m5d.4xlarge", "m5a.4xlarge", "m5ad.4xlarge", "m5n.4xlarge", "m5dn.4xlarge"]
      spot_instance_pools     = 6 # Amount of different instance that we can use
      min_size                = 1
      max_size                = 50
      desired_size            = 1
      public_ip               = false
      kubelet_extra_args      = "--node-labels=node.kubernetes.io/lifecycle=spot"
      tags = {
        "k8s.io/cluster-autoscaler/enabled"               = true,
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned",
      }
    },
  }
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
