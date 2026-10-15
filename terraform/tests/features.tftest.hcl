mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        }]
      })
    }
  }
}

# Global dummy values to satisfy required module inputs across all runs
variables {
  vpc_id                           = "vpc-1234567890"
  public_subnet_ids                = ["subnet-pub1", "subnet-pub2"]
  private_subnet_ids               = ["subnet-priv1", "subnet-priv2"]
  msk_security_group_id            = "sg-1234567890"
  msk_bootstrap_brokers_sasl_scram = "b-1.mock.kafka.amazonaws.com:9096"
  kafka_domain                     = "mock.kafka.local"
  tls_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mock-secret"
  client_cidrs                     = ["10.0.0.0/16"]
  route53_zone_id                  = "Z1234567890MOCK"
}

# Requirement 5: Verify create_dns_records = false does not require Route 53 zone ID
run "create_dns_records_disabled_without_zone_id" {
  command = plan

  variables {
    create_dns_records = false
    route53_zone_id    = null
  }
}
run "create_dns_records_enabled_with_null_zone_id" {
  command = plan

  variables {
    create_dns_records = true
    route53_zone_id    = null
  }


  expect_failures = [
    aws_lb.kafka
  ]
}



# Requirement 6: Test optional alarms, dashboards, Container Insights, and ECS Exec
# run "verify_optional_feature_flags" {
#   command = plan

#   variables {
#     enable_container_insights   = true
#     enable_execute_command      = true
#     create_alarms               = true
#     create_cloudwatch_dashboard = true
#   }

#   assert {
#     condition     = var.enable_container_insights == true
#     error_message = "Container Insights should be enabled."
#   }

#   assert {
#     condition     = var.create_cloudwatch_dashboard == true
#     error_message = "CloudWatch dashboard should be enabled."
#   }

# }

run "verify_optional_feature_flags" {
  command = plan

  variables {
    enable_container_insights   = true
    enable_execute_command      = true
    create_alarms               = true
    create_cloudwatch_dashboard = true
  }

  assert {
    condition = length([
      for s in aws_ecs_cluster.proxy.setting : s
      if s.name == "containerInsights" && s.value == "enabled"
    ]) > 0
    error_message = "Container Insights should be enabled."
  }


  assert {
    condition     = length(aws_cloudwatch_dashboard.proxy) == 1
    error_message = "CloudWatch dashboard should be created when enabled."
  }
  assert {
    condition     = aws_ecs_service.proxy.enable_execute_command == true
    error_message = "ECS Exec should be enabled."
  }
  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.proxy_log_errors) > 0 &&
      length(aws_cloudwatch_metric_alarm.unhealthy_targets) > 0 &&
      length(aws_cloudwatch_metric_alarm.low_healthy_targets) > 0 &&
      length(aws_cloudwatch_metric_alarm.high_cpu) > 0
    )

    error_message = "CloudWatch alarms should be created when alarms are enabled."
  }
}
run "verify_optional_feature_flags_disabled" {
  command = plan

  variables {
    enable_container_insights   = false
    enable_execute_command      = false
    create_alarms               = false
    create_cloudwatch_dashboard = false
  }

  # assert {
  #   condition     = aws_ecs_cluster.proxy.setting[0].value == "enabled"
  #   error_message = "Container Insights should be enabled."
  # }

  assert {
    condition = length([
      for s in aws_ecs_cluster.proxy.setting : s
      if s.name == "containerInsights" && s.value == "enabled"
    ]) == 0
    error_message = "Container Insights should be disabled."
  }
  assert {
    condition     = length(aws_cloudwatch_dashboard.proxy) == 0
    error_message = "CloudWatch dashboard should  not be created when disabled."
  }
  assert {
    condition     = output.cloudwatch_dashboard_name == null
    error_message = "CloudWatch dashboard output should be null when disabled."
  }
  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.proxy_log_errors) == 0 &&
      length(aws_cloudwatch_metric_alarm.unhealthy_targets) == 0 &&
      length(aws_cloudwatch_metric_alarm.low_healthy_targets) == 0 &&
      length(aws_cloudwatch_metric_alarm.high_cpu) == 0
    )

    error_message = "No CloudWatch alarms should be created when alarms are disabled."
  }

  assert {
    condition     = length(output.alarm_names) == 0
    error_message = "Alarm names should be empty when alarms are disabled."
  }
  assert {
    condition     = aws_ecs_service.proxy.enable_execute_command == false
    error_message = "ECS Exec should be disabled."
  }


}
# Requirement 7: Verify Autoscaling configuration attributes
run "verify_autoscaling_configurations" {
  command = plan

  variables {
    name                     = "kafka-proxy-test"
    autoscaling_min_capacity = 2
    autoscaling_max_capacity = 10
    cpu_target_percent       = 75.0
    memory_target_percent    = 80.0
    kafka_domain             = "mock.kafka.local"

  }

  assert {
    condition     = aws_appautoscaling_target.proxy.min_capacity == 2
    error_message = "Autoscaling min_capacity should match variable input."
  }

  assert {
    condition     = aws_appautoscaling_target.proxy.max_capacity == 10
    error_message = "Autoscaling max_capacity should match variable input."
  }
  # assert {
  #   condition     = aws_cpu_target_percentage == 75.0
  #   error_message = "Autoscaling cpu_target_percent should match variable input."
  # }
  # assert {
  #   condition     = aws_memory_target_percentage  == 80.0
  #   error_message = "Autoscaling memory_target_percentshould match variable input."
  # }
  assert {
    condition     = aws_appautoscaling_policy.cpu.target_tracking_scaling_policy_configuration[0].target_value == 75.0
    error_message = "Autoscaling CPU target_value should match variable input."
  }

  assert {
    condition     = aws_appautoscaling_policy.memory.target_tracking_scaling_policy_configuration[0].target_value == 80.0
    error_message = "Autoscaling memory target_value should match variable input."
  }
  assert {
    condition     = output.bootstrap_hostname != null
    error_message = "Bootstrap hostname output should not be null."
  }

  assert {
    condition     = endswith(output.bootstrap_server, ":443")
    error_message = "Bootstrap server output should end with port 443."
  }

  assert {
    condition     = output.broker_wildcard_hostname == "*.${var.kafka_domain}"
    error_message = "Broker wildcard hostname should correctly format the domain."
  }
  # Test Dashboard Output Behaviour (Enabled)
  assert {
    condition     = output.cloudwatch_dashboard_name != null
    error_message = "CloudWatch dashboard name should not be null when enabled."
  }

  # Test Alarm Output Behaviour (Enabled)
  assert {
    condition     = length(output.alarm_names) > 0
    error_message = "Alarm names list should not be empty when alarms are enabled."
  }

}