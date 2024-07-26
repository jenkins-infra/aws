data "aws_instance" "pkg_origin_jenkins_io" {
  filter {
    name   = "tag:Name"
    values = ["jenkins-pkg"]
  }
}

resource "aws_network_interface_sg_attachment" "ssh_to_pkg" {
  security_group_id    = aws_security_group.restricted_ssh.id
  network_interface_id = data.aws_instance.pkg_origin_jenkins_io.network_interface_id
}

resource "aws_network_interface_sg_attachment" "http_to_pkg" {
  security_group_id    = aws_security_group.unrestricted_http.id
  network_interface_id = data.aws_instance.pkg_origin_jenkins_io.network_interface_id
}

resource "aws_network_interface_sg_attachment" "pkg" {
  security_group_id    = aws_security_group.pkg.id
  network_interface_id = data.aws_instance.pkg_origin_jenkins_io.network_interface_id
}

resource "aws_security_group" "pkg" {
  name        = "pkg"
  description = "Custom network rules for the pkg VM (pkg.origin.jenkins AND updates.jenkins.io)"
  vpc_id      = data.aws_vpc.default.id

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_ssh" {
  for_each = [
    for ip in toset(flatten(concat(
      module.jenkins_infra_shared_data.outbound_ips["archives.jenkins.io"],        # Sync to archives.jenkins.io with SSH/Rsync
      module.jenkins_infra_shared_data.external_service_ips["ftp-osl.osuosl.org"], # Sync to OSUOSL
    ))) : ip
    if can(cidrnetmask("${ip}/32"))
  ]

  description       = "Allow outbound SSH for sync"
  security_group_id = aws_security_group.pkg.id
  cidr_ipv4         = "${each.value}/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_rsync" {
  for_each = [
    for ip in toset(flatten(concat(
      module.jenkins_infra_shared_data.outbound_ips["archives.jenkins.io"],        # Sync to archives.jenkins.io with SSH/Rsync
      module.jenkins_infra_shared_data.external_service_ips["ftp-osl.osuosl.org"], # Sync to OSUOSL
    ))) : ip
    if can(cidrnetmask("${ip}/32"))
  ]

  description       = "Allow outbound SSH for sync"
  security_group_id = aws_security_group.pkg.id
  cidr_ipv4         = "${each.value}/32"
  from_port         = 387
  ip_protocol       = "tcp"
  to_port           = 387
}
