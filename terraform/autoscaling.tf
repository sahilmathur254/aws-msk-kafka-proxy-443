resource "aws_appautoscaling_target" "proxy" {
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.proxy.name}/${aws_ecs_service.proxy.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.proxy.resource_id
  scalable_dimension = aws_appautoscaling_target.proxy.scalable_dimension
  service_namespace  = aws_appautoscaling_target.proxy.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_percent
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.name}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.proxy.resource_id
  scalable_dimension = aws_appautoscaling_target.proxy.scalable_dimension
  service_namespace  = aws_appautoscaling_target.proxy.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.memory_target_percent
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
