resource "aws_lb" "kafka" {
  name                             = var.name
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = var.public_subnet_ids
  security_groups                  = [aws_security_group.nlb.id]
  ip_address_type                  = "ipv4"
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.nlb_deletion_protection

  tags = local.common_tags
}

resource "aws_lb_target_group" "proxy" {
  name        = "${var.name}-proxy"
  port        = local.proxy_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = 120
  preserve_client_ip   = true
  proxy_protocol_v2    = false

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = tostring(local.management_port)
    path                = "/metrics"
    matcher             = "200-399"
    interval            = 15
    timeout             = 6
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "kafka_443" {
  load_balancer_arn        = aws_lb.kafka.arn
  port                     = 443
  protocol                 = "TCP"
  tcp_idle_timeout_seconds = 6000

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }

  tags = local.common_tags
}
