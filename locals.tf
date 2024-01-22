resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "random_pet" "suffix_public" {
  # You want to taint this resource in order to get a new pet
}

locals {
  aws_account_id = "200564066411"

  common_tags = {
    "scope"         = "terraform-managed"
    "repository"    = "jenkins-infra/aws"
    "cb:user"       = "dduportal"
    "cb:production" = "production"
    "cb:owner"      = "Community-Team"
    "cb-env-type"   = "external"
  }

  ## Load public keypars from the reference file
  # Each line is expected to holds an OpenSSH public key followed by a comment character ('#') and the name of the instance using the ec2 agents with this key
  ec2_agents_publickeys = compact(split("\n", file("./ec2_agents_authorized_keys")))

  # EKS related
  cik8s_cluster_name           = "cik8s-${random_string.suffix.result}"
  public_cluster_name          = "public-${random_pet.suffix_public.id}"
  autoscaler_account_namespace = "autoscaler"
  autoscaler_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"
  nlb_account_namespace        = "aws-load-balancer"
  nlb_account_name             = "aws-load-balancer-controller"
  ebs_account_namespace        = "kube-system"
  ebs_account_name             = "ebs-csi-controller-sa"
  configmap_iam_admin_accounts = [
    # Impersonated role when using the CloudBees Accounts (e.g. humans)
    {
      userarn  = "arn:aws:iam::${local.aws_account_id}:role/AWSReservedSSO_infra-admin_eaf058d61d35b904",
      username = "infra-admin",
      groups   = ["system:masters"],
    },
    # User used by infra.ci.jenkins.io to operate the cluster through terraform (including the configmap itself)
    {
      userarn  = "arn:aws:iam::${local.aws_account_id}:user/terraform-aws-production",
      username = "terraform-aws-production",
      groups   = ["system:masters"],
    },
  ]
  # AWS security groups related
  aws_security_groups = ["infraci:infra.ci.jenkins.io:20.22.6.81/32"]
}
