locals {
  ## Load public keypars from the reference file
  # Each line is expected to holds an OpenSSH public key followed by a comment character ('#') and the name of the instance using the ec2 agents with this key
  ec2_agents_publickeys = compact(split("\n", file("./ec2_agents_authorized_keys")))

  # EKS related
  cluster_name                             = "jenkins-infra-eks-${random_string.suffix.result}"
  k8s_autoscaler_service_account_namespace = "autoscaler"
  k8s_autoscaler_service_account_name      = "cluster-autoscaler-aws-cluster-autoscaler-chart"

  #AWS security groups related
  aws_security_groups = "infraci:infra.ci.jenkins.io:20.72.105.159/32, release:release.ci.jenkins.io:52.177.88.13/32"

}
