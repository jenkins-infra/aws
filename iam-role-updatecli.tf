## Identity to allow updatecli to update AMIs and associated AWS resources
data "aws_iam_user" "updatecli" {
  user_name = "updatecli"
}


resource "aws_iam_user_policy_attachment" "allow_updatecli_read_ec2" {
  user       = data.aws_iam_user.updatecli.user_name
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
      "ec2:ReadTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeImages",
      "ec2:DescribeAvailabilityZones",
    ]

    # TODO: list all resources and remove the tfsec ignore rule
    #tfsec:ignore:AWS099
    resources = ["*"]
  }
}
