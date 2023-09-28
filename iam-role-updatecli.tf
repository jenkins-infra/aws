## Identity to allow updatecli to update AMIs and associated AWS resources
## No need to create a group for only 1 user
#trivy:ignore:no-user-attached-policies
resource "aws_iam_user" "updatecli" {
  name = "updatecli"
}

resource "aws_iam_user_policy_attachment" "allow_updatecli_read_ec2" {
  user       = aws_iam_user.updatecli.name
  policy_arn = aws_iam_policy.updatecli.arn
}

resource "aws_iam_policy" "updatecli" {
  name        = "updatecli"
  path        = "/"
  description = "IAM Policy to allow updatecli to update AMIs and associated AWS resources."
  policy      = data.aws_iam_policy_document.updatecli.json
}

data "aws_iam_policy_document" "updatecli" {
  statement {
    sid    = "VisualEditor0"
    effect = "Allow"

    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeImages",
      "ec2:DescribeAvailabilityZones",
    ]

    ## Allow wildcard for resource as it's used to request AMIs with their IDs unknwon in Terraform
    #trivy:ignore:aws-iam-no-policy-wildcards
    resources = ["*"]
  }
}
