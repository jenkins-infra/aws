resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "random_pet" "suffix_public" {
  # You want to taint this resource in order to get a new pet
}

locals {
  aws_account_id = "200564066411"

  ## Load public keypars from the reference file
  # Each line is expected to holds an OpenSSH public key followed by a comment character ('#') and the name of the instance using the ec2 agents with this key
  ec2_agents_publickeys = compact(split("\n", file("./ec2_agents_authorized_keys")))

  # EKS related
  cluster_name                 = "jenkins-infra-eks-${random_string.suffix.result}"
  public_cluster_name          = "public-${random_pet.suffix_public.id}"
  autoscaler_account_namespace = "autoscaler"
  autoscaler_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"
  nlb_account_namespace        = "aws-load-balancer"
  nlb_account_name             = "aws-load-balancer-controller"
  ebs_account_namespace        = "kube-system"
  ebs_account_name             = "ebs-csi-controller-sa"
  # AWS security groups related
  aws_security_groups = ["infraci:infra.ci.jenkins.io:20.72.105.159/32", "release:release.ci.jenkins.io:52.177.88.13/32"]

}
