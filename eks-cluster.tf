# Define a KMS main key to encrypt the EKS cluster
resource "aws_kms_key" "eks" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true

  tags = {
    associated_service = "eks/${local.cluster_name}"
  }
}

# EKS Cluster definition
module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "18.30.2"
  cluster_name = local.cluster_name
  # Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = "1.22"
  # Start is inclusive, end is exclusive (!): from index 0 to index 2 (https://www.terraform.io/language/functions/slice)
  # We're using the 3 first private_subnets defined in vpc.tf for this cluster
  subnet_ids = slice(module.vpc.private_subnets, 0, 3)
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
    Environment        = "jenkins-infra-${terraform.workspace}"
    GithubRepo         = "aws"
    GithubOrg          = "jenkins-infra"
    associated_service = "eks/${local.cluster_name}"
  }

  # VPC is defined in vpc.tf
  vpc_id = module.vpc.vpc_id

  ## Manage EKS addons with module
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  eks_managed_node_groups = {
    tiny_ondemand_linux = {
      # This worker pool is expected to host the "technical" services such as pod autoscaler, etc.
      name                 = "tiny-ondemand-linux"
      instance_types       = ["t3a.xlarge"]
      capacity_type        = "ON_DEMAND"
      min_size             = 1
      max_size             = 2 # Allow manual scaling when running operations or upgrades
      desired_size         = 1
      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'"
      suspended_processes  = ["AZRebalance"]
      tags = {
        "k8s.io/cluster-autoscaler/enabled" = false # No autoscaling for these 2 machines
      },
    },
    # This list of worker pool is aimed at mixed spot instances type, to ensure that we always get the most available (e.g. the cheaper) spot size
    # as per https://aws.amazon.com/blogs/compute/cost-optimization-and-resilience-eks-with-spot-instances/
    spot_linux_4xlarge = {
      name          = "spot-linux-4xlarge"
      capacity_type = "SPOT"
      # Instances of 16 vCPUs /	64 Gb each
      instance_types      = ["m5.4xlarge", "m5d.4xlarge", "m5a.4xlarge", "m5ad.4xlarge", "m5n.4xlarge", "m5dn.4xlarge"]
      spot_instance_pools = 6 # Amount of different instance that we can use
      min_size            = 0
      max_size            = 50
      desired_size        = 1
      kubelet_extra_args  = "--node-labels=node.kubernetes.io/lifecycle=spot"
      tags = {
        "k8s.io/cluster-autoscaler/enabled"               = true,
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned",
      }
    },
  }

  # Allow egress from nodes (and pods...)
  node_security_group_additional_rules = {
    egress_jenkins_jnlp = {
      description      = "Allow egress to Jenkins TCP"
      protocol         = "TCP"
      from_port        = 50000
      to_port          = 50000
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    egress_http = {
      description      = "Allow egress to plain HTTP"
      protocol         = "TCP"
      from_port        = 80
      to_port          = 80
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
  }
}

## TODO: Proceed to renaming
# module "eks_iam_assumable_role_autoscaler_eks" {
module "eks_iam_role_autoscaler" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.5.2"
  create_role                   = true
  role_name                     = "cluster-autoscaler"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.autoscaler_account_namespace}:${local.autoscaler_account_name}"]

  tags = {
    associated_service = "eks/${local.cluster_name}"
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
