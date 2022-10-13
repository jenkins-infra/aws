# https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
resource "aws_iam_policy" "ebs_csi" {
  name        = "AmazonEBSCSIDriverPolicy"
  description = "EKS EBS CSI policy"
  policy = data.aws_iam_policy_document.ebs.json
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
