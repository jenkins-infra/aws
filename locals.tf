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

  # Tracked by 'updatecli' from the following source: https://reports.jenkins.io/jenkins-infra-data-reports/azure-net.json
  outbound_ips_trusted_ci_jenkins_io = "104.209.128.236"
  # Tracked by 'updatecli' from the following source: https://reports.jenkins.io/jenkins-infra-data-reports/azure-net.json
  outbound_ips_infra_ci_jenkins_io = "20.57.120.46 52.179.141.53 172.210.200.59 20.10.193.4"
  # Tracked by 'updatecli' from the following source: https://reports.jenkins.io/jenkins-infra-data-reports/azure-net.json
  outbound_ips_private_vpn_jenkins_io = "52.232.183.117"
  # TODO: track with updatecli
  inbound_ips_archives_jenkins_io = "46.101.121.132 2a03:b0c0:3:d0::9bc:d001"
  # TODO: track with updatecli
  inbound_ips_ftp_osl_osuosl_org = "140.211.166.134 2605:bc80:3010::134"
}
