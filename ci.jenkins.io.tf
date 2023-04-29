# Service: ci.jenkins.io

##########################################################################################################################################################
## Section: S3 Bucket used for storing Artifact and stashes
## This bucket does not need logging, versionning nor encryption as all objects are public
#tfsec:ignore:aws-s3-enable-versioning tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "ci_jenkins_io_artifacts" {
  bucket = "ci-jenkins-io-artifacts"

  force_destroy = true

  tags = {
    jenkins = "ci.jenkins.io"
  }
}

resource "aws_s3_bucket_public_access_block" "ci_jenkins_io_artifacts" {
  bucket                  = aws_s3_bucket.ci_jenkins_io_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_user" "ci_jenkins_io_artifacts" {
  name = "ci-jenkins-io-artifacts"

  tags = {
    jenkins = "ci.jenkins.io"
  }
}

resource "aws_iam_access_key" "ci_jenkins_io_artifacts" {
  user = aws_iam_user.ci_jenkins_io_artifacts.name
  # No pgp_key provided: the secret value is unencrypted in the state file (which is fine: we encrypt the state file here with sops)
}

resource "aws_iam_policy" "ci_jenkins_io_artifacts" {
  name        = "ci-jenkins-io-artifacts"
  description = "S3 Artifact Manager for ci.jenkins.io"

  policy = data.aws_iam_policy_document.ci_jenkins_io_artifacts_iam.json
}

data "aws_iam_policy_document" "ci_jenkins_io_artifacts_iam" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.ci_jenkins_io_artifacts.arn]
    effect    = "Allow"
  }
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListObjects",

    ]
    resources = [aws_s3_bucket.ci_jenkins_io_artifacts.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_user_policy_attachment" "ci_jenkins_io_artifacts" {
  user       = resource.aws_iam_user.ci_jenkins_io_artifacts.name
  policy_arn = aws_iam_policy.ci_jenkins_io_artifacts.arn
}

resource "aws_s3_bucket_policy" "ci_jenkins_io_artifacts" {
  bucket = aws_s3_bucket.ci_jenkins_io_artifacts.id
  policy = data.aws_iam_policy_document.ci_jenkins_io_artifacts_objects.json
}

data "aws_iam_policy_document" "ci_jenkins_io_artifacts_objects" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [resource.aws_iam_user.ci_jenkins_io_artifacts.arn]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]

    resources = [
      aws_s3_bucket.ci_jenkins_io_artifacts.arn,
      "${aws_s3_bucket.ci_jenkins_io_artifacts.arn}/*",
    ]
  }
}
# End of S3 Bucket Section
##########################################################################################################################################################
