locals {
  aws_account_id = "200564066411"

  common_tags = {
    "scope"          = "terraform-managed"
    "repository"     = "jenkins-infra/aws"
    "cb:user"        = "dduportal"
    "cb:environment" = "production"
    "cb:owner"       = "Community-Team"
    "cb-env-type"    = "external"
  }

  ## Load public keypars from the reference file
  # Each line is expected to holds an OpenSSH public key followed by a comment character ('#') and the name of the instance using the ec2 agents with this key
  ec2_agents_publickeys = compact(split("\n", file("./ec2_agents_authorized_keys")))
}
