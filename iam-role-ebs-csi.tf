module "eks-public_irsa_ebs" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.5.1"
  create_role                   = true
  role_name                     = local.ebs_account_name
  provider_url                  = replace(module.eks-public.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.ebs_csi.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.ebs_account_namespace}:${local.ebs_account_name}"]

  tags = {
    associated_service = "eks/${local.public_cluster_name}"
  }
}

# https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
resource "aws_iam_policy" "ebs_csi" {
  name        = "AmazonEBSCSIDriverPolicy"
  description = "EKS EBS CSI policy"
  policy      = data.aws_iam_policy_document.ebs.json
}

## No restriction on the resources: either managed outside terraform, or already scoped by conditions
#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "ebs" {
  statement {
    sid    = "ebsGrant"
    effect = "Allow"

    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }

  statement {
    sid    = "ebsEncryption"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }
}
