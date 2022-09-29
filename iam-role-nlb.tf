module "eks_iam_role_nlb" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.5.0"
  create_role                   = true
  role_name                     = "cluster-nlb"
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_nlb.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.k8s_nlb_service_account_namespace}:${local.k8s_nlb_service_account_name}"]
}

resource "aws_iam_policy" "cluster_nlb" {
  name_prefix = "cluster-nlb"
  description = "EKS cluster-nlb policy for cluster ${module.eks-public.cluster_id}"
  # JSON from https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.3/docs/install/iam_policy.json
  # Cf https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
  policy = file("iam-nlb-policy.json") #tfsec:ignore:aws-iam-no-policy-wildcards
}
