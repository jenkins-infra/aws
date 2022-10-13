# Define a KMS main key to encrypt the EKS cluster
resource "aws_kms_key" "eks-public" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true

  tags = {
    associated_service = "eks/${local.public_cluster_name}"
  }
}

# EKS Cluster definition
module "eks-public" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "18.30.1"
  cluster_name = local.public_cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = var.kubernetes_version
  # Start is inclusive, end is exclusive (!): from index 3 to index 5 (https://www.terraform.io/language/functions/slice)
  # We're using the 3 last private_subnets defined in vpc.tf for this cluster
  subnet_ids = slice(module.vpc.private_subnets, 3, 6)
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
    Environment        = "jenkins-infra-${terraform.workspace}"
    GithubRepo         = "aws"
    GithubOrg          = "jenkins-infra"
    associated_service = "eks/${local.public_cluster_name}"
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
    aws-ebs-csi-driver = {}
  }

  eks_managed_node_groups = {
    default_linux = {
      # This worker pool is expected to host the "technical" services (such as the autoscaler, the load balancer controller, etc.) and the public services like artifact-caching-proxy
      name                 = "eks-public-linux"
      instance_types       = ["t3a.xlarge"]
      capacity_type        = "ON_DEMAND"
      min_size             = 2
      max_size             = 4 # Allow manual scaling when running operations or upgrades
      desired_size         = 2
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
    # https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2462
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    },
    # nginx-ingress requires the cluster to communicate with the ingress controller
    cluster_to_node = {
      description                   = "Cluster to ingress-nginx webhook"
      protocol                      = "-1"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
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

module "eks_iam_assumable_role_autoscaler_eks_public" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.5.1"
  create_role                   = true
  role_name                     = "cluster-autoscaler-eks-public"
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.autoscaler_account_namespace}:${local.autoscaler_account_name}"]

  tags = {
    associated_service = "eks/${local.public_cluster_name}"
  }
}

module "eks-public_irsa_nlb" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.5.1"
  create_role                   = true
  role_name                     = local.nlb_account_name
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_nlb.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.nlb_account_namespace}:${local.nlb_account_name}"]

  tags = {
    associated_service = "eks/${local.public_cluster_name}"
  }
}

module "eks-public_irsa_ebs" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.5.1"
  create_role                   = true
  role_name                     = local.ebs_account_name
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.ebs_csi.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.ebs_account_namespace}:${local.ebs_account_name}"]

  tags = {
    associated_service = "eks/${local.public_cluster_name}"
  }
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
