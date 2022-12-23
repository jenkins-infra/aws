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
  version      = "19.4.2"
  cluster_name = local.public_cluster_name
  # Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = "1.23"
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

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  ## TODO: Uncomment when https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2337 is resolved
  # create_cluster_primary_security_group_tags = false
  # tags = {
  #   Environment        = "jenkins-infra-${terraform.workspace}"
  #   GithubRepo         = "aws"
  #   GithubOrg          = "jenkins-infra"
  #   associated_service = "eks/${local.public_cluster_name}"
  # }

  # VPC is defined in vpc.tf
  vpc_id = module.vpc.vpc_id

  ## Manage EKS addons with module - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
  cluster_addons = {
    coredns = {
      addon_version = "v1.8.7-eksbuild.3"
    }
    kube-proxy = {
      addon_version = "v1.23.8-eksbuild.2"
    }
    vpc-cni = {
      addon_version = "v1.11.4-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      addon_version            = "v1.11.4-eksbuild.1"
      service_account_role_arn = module.eks-public_irsa_ebs.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    default_linux = {
      # This worker pool is expected to host the "technical" services (such as the autoscaler, the load balancer controller, etc.) and the public services like artifact-caching-proxy
      name = "eks-public-linux"
      # Opt-in in to the default EKS security group to allow inter-nodes communications inside this node group
      # Ref. https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/18.16.0#security-groups
      attach_cluster_primary_security_group = true
      instance_types                        = ["t3a.xlarge"]
      capacity_type                         = "ON_DEMAND"
      min_size                              = 2
      max_size                              = 4 # Allow manual scaling when running operations or upgrades
      desired_size                          = 2
      bootstrap_extra_args                  = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'"
      suspended_processes                   = ["AZRebalance"]
      tags = {
        "k8s.io/cluster-autoscaler/enabled"                      = true # Autoscaling enabled
        "k8s.io/cluster-autoscaler/${local.public_cluster_name}" = "owned",
      },
      create_security_group = false
    },
  }

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  cluster_endpoint_public_access = true

  aws_auth_users = [
    # User impersonated when using the CloudBees IAM Accounts (e.g. humans)
    {
      userarn  = "arn:aws:iam::${local.aws_account_id}:role/infra-admin",
      username = "infra-admin",
      groups   = ["system:masters"],
    },
    # User defined in infra.ci.jenkins.io system to operate terraform
    {
      userarn  = "arn:aws:iam::${local.aws_account_id}:user/terraform-aws-production",
      username = "terraform-aws-production",
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
  version                       = "5.9.2"
  create_role                   = true
  role_name                     = "${local.autoscaler_account_name}-eks-public"
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.autoscaler_account_namespace}:${local.autoscaler_account_name}"]

  tags = {
    associated_service = "eks/${module.eks-public.cluster_name}"
  }
}

module "eks-public_irsa_nlb" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.9.2"
  create_role                   = true
  role_name                     = "${local.nlb_account_name}-eks-public"
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_nlb.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.nlb_account_namespace}:${local.nlb_account_name}"]

  tags = {
    associated_service = "eks/${module.eks-public.cluster_name}"
  }
}

module "eks-public_irsa_ebs" {
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "5.9.2"
  create_role                    = true
  role_name                      = "${local.ebs_account_name}-eks-public"
  provider_url                   = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns               = [aws_iam_policy.ebs_csi.arn]
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_fully_qualified_subjects  = ["system:serviceaccount:${local.ebs_account_namespace}:${local.ebs_account_name}"]

  tags = {
    associated_service = "eks/${module.eks-public.cluster_name}"
  }
}

# Reference the existing user for administrating the charts from github.com/jenkins-infra/kubernetes-management
data "aws_iam_user" "eks_public_charter" {
  user_name = "eks_charter"
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster_auth" "public-cluster" {
  name = module.eks-public.cluster_name
}

# Elastic IPs used for the Public Load Balancer (so that the addresses never change)
resource "aws_eip" "lb_public" {
  count = length(module.vpc.public_subnets)
  vpc   = true

  tags = {
    "Name" = "eks-public-loadbalancer-external-${count.index}"
  }
}
