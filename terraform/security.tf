resource "aws_security_group" "nlb" {
  name        = "${var.name}-nlb"
  description = "Restricts public Kafka TLS ingress to approved client CIDRs"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "nlb_443" {
  for_each = var.client_cidrs

  security_group_id = aws_security_group.nlb.id
  description       = "Kafka TLS from approved client CIDR ${each.value}"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

resource "aws_security_group" "proxy" {
  name        = "${var.name}-proxy"
  description = "Kroxylicious tasks; ingress only from NLB"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_proxy" {
  security_group_id            = aws_security_group.nlb.id
  description                  = "NLB data-plane traffic to proxy tasks"
  ip_protocol                  = "tcp"
  from_port                    = local.proxy_port
  to_port                      = local.proxy_port
  referenced_security_group_id = aws_security_group.proxy.id
}

resource "aws_vpc_security_group_egress_rule" "nlb_health_to_proxy" {
  security_group_id            = aws_security_group.nlb.id
  description                  = "NLB health checks to proxy management endpoint"
  ip_protocol                  = "tcp"
  from_port                    = local.management_port
  to_port                      = local.management_port
  referenced_security_group_id = aws_security_group.proxy.id
}

resource "aws_vpc_security_group_ingress_rule" "proxy_from_nlb" {
  security_group_id            = aws_security_group.proxy.id
  description                  = "Kafka TLS stream from NLB"
  ip_protocol                  = "tcp"
  from_port                    = local.proxy_port
  to_port                      = local.proxy_port
  referenced_security_group_id = aws_security_group.nlb.id
}

resource "aws_vpc_security_group_ingress_rule" "proxy_health_from_nlb" {
  security_group_id            = aws_security_group.proxy.id
  description                  = "Private HTTP health check from NLB"
  ip_protocol                  = "tcp"
  from_port                    = local.management_port
  to_port                      = local.management_port
  referenced_security_group_id = aws_security_group.nlb.id
}

resource "aws_vpc_security_group_egress_rule" "proxy_to_msk" {
  security_group_id            = aws_security_group.proxy.id
  description                  = "Kroxylicious to private MSK SASL/SCRAM TLS listener"
  ip_protocol                  = "tcp"
  from_port                    = var.msk_broker_port
  to_port                      = var.msk_broker_port
  referenced_security_group_id = var.msk_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "proxy_https" {
  security_group_id = aws_security_group.proxy.id
  description       = "HTTPS for image retrieval and AWS service APIs through NAT or endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "msk_from_proxy" {
  count = var.manage_msk_security_group_ingress ? 1 : 0

  security_group_id            = var.msk_security_group_id
  description                  = "SASL/SCRAM TLS from ${var.name} Kroxylicious tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.msk_broker_port
  to_port                      = var.msk_broker_port
  referenced_security_group_id = aws_security_group.proxy.id
}
