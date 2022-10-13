resource "aws_iam_policy" "cluster_nlb" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "EKS cluster-nlb policy"
  # JSON from https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.3/docs/install/iam_policy.json
  # Cf https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
  policy = file("iam-nlb-policy.json") #tfsec:ignore:aws-iam-no-policy-wildcards
}
