resource "aws_cloudwatch_log_metric_filter" "proxy_errors" {
  name           = "${var.name}-errors"
  log_group_name = aws_cloudwatch_log_group.proxy.name
  pattern        = "ERROR"

  metric_transformation {
    name          = "ProxyLogErrors"
    namespace     = "KafkaProxy/${var.name}"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "proxy_log_errors" {
  alarm_name          = "${var.name}-proxy-log-errors"
  alarm_description   = "Kroxylicious emitted ERROR-level log events."
  namespace           = "KafkaProxy/${var.name}"
  metric_name         = "ProxyLogErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns
  ok_actions          = var.alarm_action_arns
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name}-unhealthy-targets"
  alarm_description   = "One or more Kroxylicious NLB targets are unhealthy."
  namespace           = "AWS/NetworkELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = var.alarm_action_arns
  ok_actions          = var.alarm_action_arns

  dimensions = {
    LoadBalancer = aws_lb.kafka.arn_suffix
    TargetGroup  = aws_lb_target_group.proxy.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "low_healthy_targets" {
  alarm_name          = "${var.name}-healthy-targets-below-two"
  alarm_description   = "Fewer than two healthy proxy targets removes task-level redundancy."
  namespace           = "AWS/NetworkELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 2
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = var.alarm_action_arns
  ok_actions          = var.alarm_action_arns

  dimensions = {
    LoadBalancer = aws_lb.kafka.arn_suffix
    TargetGroup  = aws_lb_target_group.proxy.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.name}-high-cpu"
  alarm_description   = "Proxy service CPU remained high after autoscaling response window."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns
  ok_actions          = var.alarm_action_arns

  dimensions = {
    ClusterName = aws_ecs_cluster.proxy.name
    ServiceName = aws_ecs_service.proxy.name
  }
}

resource "aws_cloudwatch_dashboard" "proxy" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "NLB flows"
          region = local.aws_region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/NetworkELB", "NewFlowCount", "LoadBalancer", aws_lb.kafka.arn_suffix],
            [".", "ActiveFlowCount", ".", ".", { stat = "Average" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Target health"
          region = local.aws_region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/NetworkELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.proxy.arn_suffix, "LoadBalancer", aws_lb.kafka.arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS utilisation"
          region = local.aws_region
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.proxy.name, "ServiceName", aws_ecs_service.proxy.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Recent proxy errors"
          region = local.aws_region
          query  = "SOURCE '${aws_cloudwatch_log_group.proxy.name}' | fields @timestamp, @message | filter @message like /ERROR|Exception/ | sort @timestamp desc | limit 50"
          view   = "table"
        }
      }
    ]
  })
}
