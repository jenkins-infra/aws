data "aws_instance" "usage_jenkins_io" {

  filter {
    name   = "tag:Name"
    values = ["jenkins-usage"]
  }
}

resource "aws_network_interface_sg_attachment" "ssh_to_usage" {
  security_group_id    = aws_security_group.restricted_ssh.id
  network_interface_id = data.aws_instance.usage_jenkins_io.network_interface_id
}
