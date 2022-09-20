resource "aws_route53_zone" "default" {
  name = var.domain_name
}

resource "aws_route53_record" "a_record" {
  domain = aws_route53_zone.default.zone_id
  type   = "A"
  ttl    = 60
  name   = "@"
  value  = digitalocean_loadbalancer.ingress_load_balancer.ip
}

# DNS record for repo.aws.jenkins.io (https://github.com/jenkins-infra/helpdesk/issues/2752)
resource "aws_route53_record" "cname_redirect" {
  domain = aws_route53_zone.default.zone_id
  type   = "CNAME"
  ttl    = 60
  name   = "repo"
  value  = "@"
}
