## Identity for Jenkins Controller infra.ci.jenkins.io
data "aws_iam_user" "jenkins_infra_ci" {
  user_name = "jenkins-infra-ci"
}

resource "aws_iam_policy" "jenkins_ec2_agents" {
  # IAM Policy from https://plugins.jenkins.io/ec2/#user-content-iam-setup
  name        = "jenkins_ec2_agents"
  path        = "/"
  description = "IAM Policy to allow a Jenkins Controller to start and manage EC2 agents with the 'ec2' plugin."

  policy = data.aws_iam_policy_document.jenkins_ec2_agents.json
}

## Allow wildcard for resource as the EC2 instance IDs are not known in advance
#trivy:ignore:AVD-AWS-0342 trivy:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "jenkins_ec2_agents" {
  statement {
    sid    = "Stmt1312295543082"
    effect = "Allow"

    actions = [
      "ec2:DescribeSpotInstanceRequests",
      "ec2:DescribeSpotPriceHistory",
      "ec2:CancelSpotInstanceRequests",
      "ec2:GetConsoleOutput",
      "ec2:RequestSpotInstances",
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeInstances",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeRegions",
      "ec2:DescribeImages",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "iam:ListInstanceProfilesForRole",
      "iam:PassRole",
      "ec2:GetPasswordData"
    ]

    resources = ["*"]
  }
}


resource "aws_iam_user_policy_attachment" "allow_ec2_on_infraci" {
  user       = data.aws_iam_user.jenkins_infra_ci.user_name
  policy_arn = aws_iam_policy.jenkins_ec2_agents.arn
}

## Identity for Jenkins Controller ci.jenkins.io
data "aws_iam_user" "jenkins_ci" {
  user_name = "jenkins-ci"
}

resource "aws_iam_user_policy_attachment" "allow_ec2_on_ci" {
  user       = data.aws_iam_user.jenkins_ci.user_name
  policy_arn = aws_iam_policy.jenkins_ec2_agents.arn
}

resource "aws_key_pair" "ec2_agents" {
  for_each   = toset(local.ec2_agents_publickeys)
  key_name   = "ec2_agents_${trimspace(element(split("#", each.key), 1))}"
  public_key = trimspace(element(split("#", each.key), 0))

  tags = {
    jenkins = trimspace(element(split("#", each.key), 1))
  }
}


## Allow all agents to egress to the internet
#trivy:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group" "ec2_agents_security" {
  for_each = toset(local.aws_security_groups)

  name        = "ec2_agents_${trimspace(element(split(":", each.key), 0))}"
  description = "Allow ${trimspace(element(split(":", each.key), 1))} to connect to EC2 agents"

  ingress {
    description = "Allow SSH from ${trimspace(element(split(":", each.key), 1))}"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "${trimspace(element(split(":", each.key), 2))}" # this AKS cluster outside IP
    ]
  }

  ## egress for DNS, HTTP, HTTPS and SSH only
  egress {
    description = "Allow outgoing SSH requests from agents"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow outgoing DNS requests from agents"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow outgoing HTTP requests from agents"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow outgoing HTTPS requests from agents"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow outgoing JNLP requests from agents"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow outgoing WinRM HTTP requests from agents"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow outgoing WinRM HTTPS requests from agents"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    jenkins = trimspace(element(split(":", each.key), 1))
  }
}
