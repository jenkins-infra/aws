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
  version      = "19.7.0"
  cluster_name = local.cluster_name
  # Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = "1.24"
  # Start is inclusive, end is exclusive (!): from index 0 to index 2 (https://www.terraform.io/language/functions/slice)
  # We're using the 3 first private_subnets defined in vpc.tf for this cluster
  subnet_ids = slice(module.vpc.private_subnets, 0, 3)
  # Required to allow EKS service accounts to authenticate to AWS API through OIDC (and assume IAM roles)
  # useful for autoscaler, EKS addons and any AWS APi usage
  enable_irsa = true

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  cluster_endpoint_public_access = true

  create_cluster_primary_security_group_tags = false

  # Do not use interpolated values from `local` in either keys and values of provided tags (or `cluster_tags)
  # To avoid having and implicit dependency to a resource not available when parsing the module (infamous errror `Error: Invalid for_each argument`)
  # Ref. same error as having a `depends_on` in https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2337
  tags = {
    Environment = "jenkins-infra-${terraform.workspace}"
    GithubRepo  = "aws"
    GithubOrg   = "jenkins-infra"

    associated_service = "eks/cik8s"
  }

  # VPC is defined in vpc.tf
  vpc_id = module.vpc.vpc_id

  ## Manage EKS addons with module - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
  # See new versions with `aws eks describe-addon-versions --kubernetes-version <k8s-version> --addon-name <addon>`
  cluster_addons = {
    # https://github.com/coredns/coredns/releases
    coredns = {
      addon_version = "v1.9.3-eksbuild.2"
    }
    # Kube-proxy on an Amazon EKS cluster has the same compatibility and skew policy as Kubernetes
    # See https://kubernetes.io/releases/version-skew-policy/#kube-proxy
    kube-proxy = {
      addon_version = "v1.24.9-eksbuild.1"
    }
    # https://github.com/aws/amazon-vpc-cni-k8s/releases
    vpc-cni = {
      addon_version = "v1.12.2-eksbuild.1"
    }
    # https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/CHANGELOG.md
    aws-ebs-csi-driver = {
      addon_version            = "v1.16.0-eksbuild.1"
      service_account_role_arn = module.eks_irsa_ebs.iam_role_arn
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
      attach_cluster_primary_security_group = true
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
      attach_cluster_primary_security_group = true
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

module "eks_iam_role_autoscaler" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.11.1"
  create_role                   = true
  role_name                     = "${local.autoscaler_account_name}-eks"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.autoscaler_account_namespace}:${local.autoscaler_account_name}"]

  tags = {
    associated_service = "eks/${module.eks.cluster_name}"
  }
}

module "eks_irsa_ebs" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.11.1"
  create_role                   = true
  role_name                     = "${local.ebs_account_name}-eks"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.ebs_csi.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.ebs_account_namespace}:${local.ebs_account_name}"]

  tags = {
    associated_service = "eks/${module.eks.cluster_name}"
  }
}

# Reference the existing user for administrating the charts from github.com/jenkins-infra/charts
data "aws_iam_user" "eks_charter" {
  user_name = "eks_charter"
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
