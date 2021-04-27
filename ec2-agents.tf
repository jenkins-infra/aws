
# This keypair shall be used to allow the Jenkins controller infra.ci to connect to the EC2 agents
resource "aws_key_pair" "ec2_agents_infraci" {
  key_name   = "ec2_agents_infraci"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDYlEZmGs43NHtJysZpSJX/THB2JBcCP0o+8ijJVAADhzuRYE5Jdd+dwdCWyGzGc8r2pxdw+1l3NHHkhRqTWIgH9h77VLnavrqDf6dTuC05q4RTBw5E6AknKB3L0a4IzpXtvT+MbdkkJaNEFWpK63oGSxbO2kaTUXzYiJg/BnpMo8gKyeF1t1RBZ249xgWqmb4SDkM7hOLC7HF8rJjHXNFvhBAm99aWwr0MhFwmEp6fRAiI5AC52owIewXN9dkXs8oMXjQ4J6g7dO5Vwdu2M19Uk0DbaqEJmngoSYtOikpkFSlnJO3iOqYUXh6uEZLd1OjZbxbcvnmxMlI6UfKkVaKGWzLb6G8yz+Ahz9oxKmq11QsUoMedHZlwHNgPpJ+TS3p5TlDZYGsuVRm7EnMN0+KecXzoZk6i/kJO+uQ0oMxdtZCYVlwdTiOW/85WqB7lSVokIWAkRmV89kHEbgSJLgrH9aXr4xw2jhzN+F9HT2Z5mOoVU3Exkursu/bXhdocIhdtXQVBDIA0hcvouUGar6Db7VK6NQeJoAWUVVELhBZP+rGhbg5WjGZANPPi01VMIDhks5KXZt0AtaQxpZCaynbasm0g7fHvy+BP3bTQcpa95hBWYL0tjon5BPLTkzK4q282pQluba0bralLDgF0SoNw4F83w/hu7YwHMoSC9Njzcw== jenkins-infra@jenkins.io"

  tags = {
    jenkins = "infra.ci.jenkins.io"
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
