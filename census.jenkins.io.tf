data "aws_instance" "census_jenkins_io" {
  filter {
    name   = "tag:Name"
    values = ["jenkins-census"]
  }
}

resource "aws_network_interface_sg_attachment" "ssh_to_census" {
  security_group_id    = aws_security_group.restricted_ssh.id
  network_interface_id = data.aws_instance.census_jenkins_io.network_interface_id
}
