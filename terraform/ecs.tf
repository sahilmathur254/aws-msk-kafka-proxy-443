resource "aws_cloudwatch_log_group" "proxy" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_ecs_cluster" "proxy" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "proxy" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.proxy_cpu)
  memory                   = tostring(var.proxy_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = var.kroxylicious_image
      essential = true

      entryPoint = ["/bin/sh", "-c"]
      command    = [local.startup_script]

      environment = [
        {
          name  = "KROXY_CONFIG_B64"
          value = base64encode(local.proxy_config)
        },
        {
          name  = "KROXYLICIOUS_ROOT_LOG_LEVEL"
          value = "INFO"
        },
        {
          name  = "JAVA_OPTIONS"
          value = "-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"
        }
      ]

      secrets = [
        {
          name      = "TLS_CERTIFICATE"
          valueFrom = "${var.tls_secret_arn}:certificate::"
        },
        {
          name      = "TLS_PRIVATE_KEY"
          valueFrom = "${var.tls_secret_arn}:private_key::"
        }
      ]

      portMappings = [
        {
          name          = "kafka-proxy"
          containerPort = local.proxy_port
          hostPort      = local.proxy_port
          protocol      = "tcp"
        },
        {
          name          = "management"
          containerPort = local.management_port
          hostPort      = local.management_port
          protocol      = "tcp"
        }
      ]

      linuxParameters = {
        initProcessEnabled = true
      }

      readonlyRootFilesystem = false
      stopTimeout            = 120

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.proxy.name
          awslogs-region        = local.aws_region
          awslogs-stream-prefix = "proxy"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "proxy" {
  name                               = var.name
  cluster                            = aws_ecs_cluster.proxy.id
  task_definition                    = aws_ecs_task_definition.proxy.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  availability_zone_rebalancing      = "ENABLED"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  enable_execute_command             = var.enable_execute_command
  propagate_tags                     = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.proxy.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.proxy.arn
    container_name   = local.container_name
    container_port   = local.proxy_port
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener.kafka_443,
    aws_iam_role_policy_attachment.execution_base,
    aws_iam_role_policy.execution_tls_secret
  ]

  tags = local.common_tags
}
