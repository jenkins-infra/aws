# Define a KMS main key to encrypt the EKS cluster
resource "aws_kms_key" "eks_public" {
  description         = "EKS Secret Encryption Key for the cluster ${local.public_cluster_name}"
  enable_key_rotation = true

  tags = merge(local.common_tags, {
    associated_service = "eks/${local.public_cluster_name}"
  })
}

# EKS Cluster definition
module "eks-public" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "19.21.0"
  cluster_name = local.public_cluster_name
  # Kubernetes version in format '<MINOR>.<MINOR>', as per https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = "1.27"
  # Start is inclusive, end is exclusive (!): from index 3 to index 5 (https://www.terraform.io/language/functions/slice)
  # We're using the 3 last private_subnets defined in vpc.tf for this cluster
  subnet_ids = slice(module.vpc.private_subnets, 3, 6)
  # Required to allow EKS service accounts to authenticate to AWS API through OIDC (and assume IAM roles)
  # useful for autoscaler, EKS addons, NLB and any AWS API usage
  # See list at https://github.com/terraform-aws-modules/terraform-aws-iam/tree/master/modules/iam-role-for-service-accounts-eks
  enable_irsa = true

  # Specifying the kubernetes provider to use for this cluster
  # Note: this should be done AFTER initial cluster creation (bootstrap)
  providers = {
    kubernetes = kubernetes.eks-public
  }

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks_public.arn
    resources        = ["secrets"]
  }

  create_cluster_primary_security_group_tags = false

  # Do not use interpolated values from `local` in either keys and values of provided tags (or `cluster_tags)
  # To avoid having and implicit dependency to a resource not available when parsing the module (infamous errror `Error: Invalid for_each argument`)
  # Ref. same error as having a `depends_on` in https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2337
  tags = merge(local.common_tags, {
    Environment        = "jenkins-infra-${terraform.workspace}"
    GithubRepo         = "aws"
    GithubOrg          = "jenkins-infra"
    associated_service = "eks/eks-public"
  })

  # VPC is defined in vpc.tf
  vpc_id = module.vpc.vpc_id

  ## Manage EKS addons with module - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
  # See new versions with `aws eks describe-addon-versions --kubernetes-version <k8s-version> --addon-name <addon>`
  cluster_addons = {
    # https://github.com/coredns/coredns/releases
    coredns = {
      addon_version = "v1.10.1-eksbuild.7"
    }
    # Kube-proxy on an Amazon EKS cluster has the same compatibility and skew policy as Kubernetes
    # See https://kubernetes.io/releases/version-skew-policy/#kube-proxy
    kube-proxy = {
      addon_version = "v1.27.10-eksbuild.2"
    }
    # https://github.com/aws/amazon-vpc-cni-k8s/releases
    vpc-cni = {
      addon_version = "v1.16.4-eksbuild.2"
    }
    # https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/CHANGELOG.md
    aws-ebs-csi-driver = {
      addon_version = "v1.28.0-eksbuild.1"
    }
  }

  eks_managed_node_group_defaults = {
    instance_types       = ["t3a.xlarge"]
    capacity_type        = "ON_DEMAND"
    bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'"
    suspended_processes  = ["AZRebalance"]
    tags = merge(local.common_tags, {
      "k8s.io/cluster-autoscaler/enabled"                      = true # Autoscaling enabled
      "k8s.io/cluster-autoscaler/${local.public_cluster_name}" = "owned",
    }),
  }

  eks_managed_node_groups = {
    # 1 subnet per node poole == 1 AZ per node pool
    default_linux_az1 = {
      # This worker pool is expected to host the "technical" services (such as the autoscaler, the load balancer controller, etc.) and the public services like artifact-caching-proxy
      name         = "eks-public-linux-az1"
      min_size     = 0
      max_size     = 4
      desired_size = 2
      subnet_ids   = [element(module.vpc.private_subnets, 0)]
    },
  }

  create_aws_auth_configmap = true
  manage_aws_auth_configmap = true

  cluster_endpoint_public_access = true

  aws_auth_users = local.configmap_iam_admin_accounts

  aws_auth_accounts = [
    local.aws_account_id,
  ]
}

# Reference to allow configuration of the Terraform's kubernetes provider (in providers.tf)
data "aws_eks_cluster_auth" "public-cluster" {
  name = module.eks-public.cluster_name
}
