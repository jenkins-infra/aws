
# This keypair shall be used to allow the Jenkins controller infra.ci to connect to the EC2 agents
resource "aws_key_pair" "ec2_agents_infraci" {
  key_name   = "ec2_agents_infraci"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILoYAkQkqbIyQWO3uwa6ZiJa5xBbEJ6yOzP8MDGnuXdg jenkins-infra@jenkins.io"
}
