# https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
resource "aws_iam_policy" "ebs_csi" {
  name        = "AmazonEBSCSIDriverPolicy"
  description = "EKS EBS CSI policy"
  policy      = data.aws_iam_policy_document.ebs.json
}

resource "aws_iam_policy" "cluster_nlb" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "EKS cluster-nlb policy"
  # JSON from https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
  # Cf https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
  policy = file("iam-nlb-policy.json") #tfsec:ignore:aws-iam-no-policy-wildcards
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name_prefix = "cluster-autoscaler"
  description = "EKS cluster-autoscaler policy"
  policy      = data.aws_iam_policy_document.cluster_autoscaler.json
}

## No restriction on the resources: either managed outside terraform, or already scoped by conditions
#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "ec2"
    effect = "Allow"

    actions = [
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ec2AutoScaling"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
    ]


    resources = ["*"]
  }

  statement {
    sid    = "clusterAutoscalerOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}

## https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md#set-up-driver-permission
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

  statement {
    sid    = "ec2VolumesManagement"
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }

  statement {
    sid    = "ec2CreateTags"
    effect = "Allow"

    actions = [
      "ec2:CreateTags"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateVolume", "CreateSnapshot"]
    }
  }

  statement {
    sid    = "ec2DeleteTags"
    effect = "Allow"

    actions = [
      "ec2:DeleteTags"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVolume"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVolume"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVolume"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteVolume"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteVolume"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteVolume"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteSnapshot"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DeleteSnapshot"
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

}
