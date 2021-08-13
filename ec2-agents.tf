resource "aws_key_pair" "ec2_agents" {
  for_each   = toset(local.ec2_agents_publickeys)
  key_name   = "ec2_agents_${trimspace(element(split("#", each.key), 1))}"
  public_key = trimspace(element(split("#", each.key), 0))

  tags = {
    jenkins = trimspace(element(split("#", each.key), 1))
  }
}

resource "aws_security_group" "ec2_agents_infraci" {
  name        = "ec2_agents_infraci"
  description = "Allow infra.ci to connect to EC2 agents"

  ingress {
    description = "Allow SSH from infra.ci"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "52.177.88.13/32" # AKS cluster outside IP
    ]
  }

  ## egress for DNS, HTTP, HTTPS and SSH only
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }

  tags = {
    jenkins = "infra.ci.jenkins.io"
  }
}

resource "aws_security_group" "ec2_agents_release" {
  name        = "ec2_agents_release"
  description = "Allow release.ci to connect to EC2 agents"

  ingress {
    description = "Allow SSH from release.ci"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "52.177.88.13/32" # AKS cluster outside IP
    ]
  }

  ## egress for DNS, HTTP, HTTPS and SSH only
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:AWS009
  }

  tags = {
    jenkins = "release.ci.jenkins.io"
  }
}
