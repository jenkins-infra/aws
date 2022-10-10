# Define a KMS main key to encrypt the EKS cluster
resource "aws_kms_key" "eks-public" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true
}

# EKS Cluster definition
module "eks-public" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "18.30.0"
  cluster_name = local.public_cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = var.kubernetes_version
  subnet_ids = module.vpc.public_subnets
  # Required to allow EKS service accounts to authenticate to AWS API through OIDC (and assume IAM roles)
  # useful for autoscaler, EKS addons, NLB and any AWS API usage
  # See list at https://github.com/terraform-aws-modules/terraform-aws-iam/tree/master/modules/iam-role-for-service-accounts-eks
  enable_irsa = true

  # Specifying the kubernetes provider to use for this cluster
  providers = {
    kubernetes = kubernetes.eks-public
  }

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
    arm-4c16g = {
      # This worker pool is expected to host public services such as artifact-caching-proxy, etc.
      name                 = "arm-4c16g"
      ami_type             = "AL2_ARM_64"
      instance_types       = ["t4g.xlarge"]
      capacity_type        = "ON_DEMAND"
      min_size             = 1
      max_size             = local.public_cluster_max_size # Allow manual scaling when running operations or upgrades
      desired_size         = 1
      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'"
      suspended_processes  = ["AZRebalance"]
      tags = {
        "k8s.io/cluster-autoscaler/enabled"                      = true # Autoscaling enabled
        "k8s.io/cluster-autoscaler/${local.public_cluster_name}" = "owned",
      },
    },
  }

  # Allow egress from nodes (and pods...)
  node_security_group_additional_rules = {
    egress_http = {
      description      = "Allow egress to plain HTTP"
      protocol         = "TCP"
      from_port        = 80
      to_port          = 80
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    # https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2462
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_users = [
    # User impersonated when using the CloudBees IAM Accounts (e.g. humans)
    {
      userarn  = "arn:aws:iam::${local.aws_account_id}:role/infra-admin",
      username = "infra-admin",
      groups   = ["system:masters"],
    },
    # User defined in infra.ci.jenkins.io system to operate terraform
    {
      userarn  = "arn:aws:iam::${local.aws_account_id}:user/production-terraform",
      username = "production-terraform",
      groups   = ["system:masters"],
    },
    # User for administrating the charts from github.com/jenkins-infra/kubernetes-management
    {
      userarn  = data.aws_iam_user.eks_public_charter.arn,
      username = data.aws_iam_user.eks_public_charter.user_name,
      groups   = ["system:masters"],
    },
  ]

  aws_auth_accounts = [
    local.aws_account_id,
  ]
}

# Reference the existing user for administrating the charts from github.com/jenkins-infra/kubernetes-management
data "aws_iam_user" "eks_public_charter" {
  user_name = "eks_charter"
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster" "public-cluster" {
  name = module.eks-public.cluster_id
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster_auth" "public-cluster" {
  name = module.eks-public.cluster_id
}
