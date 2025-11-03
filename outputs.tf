resource "local_file" "jenkins_infra_data_report" {
  content = jsonencode({
    "pkg.origin.jenkins.io" = {
      "service_ips" = {
        "ipv4" = data.aws_instance.pkg_origin_jenkins_io.public_ip,
      }
      "outbound_ips" = {
        "ipv4" = data.aws_instance.pkg_origin_jenkins_io.public_ip,
      }
    },
  })
  filename = "${path.module}/jenkins-infra-data-reports/aws.json"
}
output "jenkins_infra_data_report" {
  value = local_file.jenkins_infra_data_report.content
}
