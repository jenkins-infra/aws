# Define a KMS main key to encrypt the EKS cluster
resource "aws_kms_key" "eks-public" {
  description         = "EKS Secret Encryption Key"
  enable_key_rotation = true
}

# EKS Cluster definition
module "eks-public" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "18.29.0"
  cluster_name = local.public_cluster_name
  # From https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  cluster_version = var.kubernetes_version
  subnet_ids      = module.vpc.public_subnets
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

# resource "aws_lb" "nlb_public" {
#   name               = "nlb-public"
#   internal           = false
#   load_balancer_type = "network"
#   subnets            = [for subnet in module.vpc.public_subnets : subnet.id]

#   enable_deletion_protection = true

#   tags = {
#     Environment = "jenkins-infra-${terraform.workspace}"
#     GithubRepo  = "aws"
#     GithubOrg   = "jenkins-infra"
#   }
# }

# resource "aws_route53_zone" "aws_jenkins_io" {
#   name = var.domain_name
# }

# resource "aws_route53_record" "a_record" {
#   zone_id = aws_route53_zone.aws_jenkins_io.zone_id
#   name    = "@"
#   type    = "A"
#   ttl     = 60
#   records = [nlb_public.public_ip]
# }

# # DNS record for repo.aws.jenkins.io (https://github.com/jenkins-infra/helpdesk/issues/2752)
# resource "aws_route53_record" "cname_redirect" {
#   zone_id = aws_route53_zone.aws_jenkins_io.zone_id
#   name    = "repo"
#   type    = "CNAME"
#   ttl     = 60
#   records = ["repo.${aws_jenkins_io.name}"]
# }

# Reference the existing user for administrating the charts from github.com/jenkins-infra/charts
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
