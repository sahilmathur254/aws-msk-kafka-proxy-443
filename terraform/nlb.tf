# The NLB is intentionally public: this module exists to provide the restricted
# external Kafka endpoint. Ingress remains limited by client_cidrs.
#trivy:ignore:AVD-AWS-0053
resource "aws_lb" "kafka" {
  name                             = var.name
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = var.public_subnet_ids
  security_groups                  = [aws_security_group.nlb.id]
  ip_address_type                  = "ipv4"
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.nlb_deletion_protection

  lifecycle {
    precondition {
      condition     = var.allow_unrestricted_client_cidrs || !contains(var.client_cidrs, "0.0.0.0/0")
      error_message = "client_cidrs must not include 0.0.0.0/0 unless allow_unrestricted_client_cidrs is true."
    }

    precondition {
      condition     = var.allow_mutable_image_tag || can(regex("@sha256:[a-f0-9]{64}$", var.kroxylicious_image))
      error_message = "kroxylicious_image must be pinned by sha256 digest unless allow_mutable_image_tag is true."
    }

    precondition {
      condition     = contains(keys(local.fargate_memory_by_cpu), tostring(var.proxy_cpu)) && contains(lookup(local.fargate_memory_by_cpu, tostring(var.proxy_cpu), []), var.proxy_memory)
      error_message = "proxy_cpu and proxy_memory must be a supported AWS Fargate CPU and memory combination."
    }

    precondition {
      condition     = var.autoscaling_min_capacity <= var.autoscaling_max_capacity && var.desired_count >= var.autoscaling_min_capacity && var.desired_count <= var.autoscaling_max_capacity
      error_message = "desired_count must be within autoscaling capacity bounds, and the minimum must not exceed the maximum."
    }

    precondition {
      condition     = !var.create_dns_records || var.route53_zone_id != null
      error_message = "route53_zone_id must be provided when create_dns_records is true."
    }
  }

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
