data "aws_vpc" "default" {
  id = "vpc-70a4b915"
}

resource "aws_security_group" "restricted_ssh" {
  name        = "restricted-ssh"
  description = "Allow inbound SSH only from trusted sources (admins or VPN)"
  vpc_id      = data.aws_vpc.default.id

  tags = local.common_tags
}

resource "aws_security_group" "unrestricted_http" {
  name        = "unrestricted-http"
  description = "Allow HTTP(S) from everywhere (public services)"
  vpc_id      = data.aws_vpc.default.id

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_admins" {
  for_each = toset([
    for ip in flatten(concat(
      module.jenkins_infra_shared_data.outbound_ips["trusted.ci.jenkins.io"],              # permanent agent of update_center2
      module.jenkins_infra_shared_data.outbound_ips["trusted.sponsorship.ci.jenkins.io"],  # ephemeral agents for crawler
      module.jenkins_infra_shared_data.outbound_ips["privatek8s.jenkins.io"],              # VPN VM
      module.jenkins_infra_shared_data.outbound_ips["infracijenkinsioagents1.jenkins.io"], # Terraform management and Docker-packaging build
      module.jenkins_infra_shared_data.outbound_ips["private.vpn.jenkins.io"],             # connections routed through the VPN
    )) : ip
    if can(cidrnetmask("${ip}/32"))
  ])

  description       = "Allow admin (or platform) IPv4 for inbound SSH"
  security_group_id = aws_security_group.restricted_ssh.id
  cidr_ipv4         = "${each.value}/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

## We WANT inbound from everywhere
#trivy:ignore:avd-aws-0107
resource "aws_vpc_security_group_ingress_rule" "allow_http_from_internet" {
  description       = "Allow HTTP from everywhere (public Internet)"
  security_group_id = aws_security_group.unrestricted_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

## We WANT inbound from everywhere
#trivy:ignore:avd-aws-0107
resource "aws_vpc_security_group_ingress_rule" "allow_https_from_internet" {
  description       = "Allow HTTP from everywhere (public Internet)"
  security_group_id = aws_security_group.unrestricted_http.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

## We WANT egress to internet (APT at least, but also outbound azcopy on some machines)
#trivy:ignore:avd-aws-0104
resource "aws_vpc_security_group_egress_rule" "allow_http_to_internet" {
  description       = "Allow HTTP to everywhere (public Internet)"
  security_group_id = aws_security_group.unrestricted_http.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

## We WANT egress to internet (APT at least, but also outbound azcopy on some machines)
#trivy:ignore:avd-aws-0104
resource "aws_vpc_security_group_egress_rule" "allow_https_to_internet" {
  description       = "Allow HTTPS to everywhere (public Internet)"
  security_group_id = aws_security_group.unrestricted_http.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_puppet_to_puppetmaster" {
  description       = "Allow Puppet protocol to the Puppet master"
  security_group_id = aws_security_group.unrestricted_http.id

  # Ref. https://github.com/jenkins-infra/azure/blob/main/puppet.jenkins.io.tf
  # TODO: automate retrieval of this IP with updatecli
  cidr_ipv4   = "20.12.27.65/32"
  from_port   = 8140
  ip_protocol = "tcp"
  to_port     = 8140
}
