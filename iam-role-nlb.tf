module "eks_iam_role_nlb" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.5.0"
  create_role                   = true
  role_name                     = local.k8s_nlb_service_account_name
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_nlb.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.k8s_nlb_service_account_namespace}:${local.k8s_nlb_service_account_name}"]
}

resource "aws_iam_policy" "cluster_nlb" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "EKS cluster-nlb policy"
  # JSON from https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.3/docs/install/iam_policy.json
  # Cf https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
  policy = file("iam-nlb-policy.json") #tfsec:ignore:aws-iam-no-policy-wildcards
}
