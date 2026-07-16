resource "aws_route53_record" "bootstrap" {
  zone_id = var.route53_zone_id
  name    = local.bootstrap_hostname
  type    = "A"

  alias {
    name                   = aws_lb.kafka.dns_name
    zone_id                = aws_lb.kafka.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "brokers" {
  zone_id = var.route53_zone_id
  name    = "*.${var.kafka_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.kafka.dns_name
    zone_id                = aws_lb.kafka.zone_id
    evaluate_target_health = true
  }
}
