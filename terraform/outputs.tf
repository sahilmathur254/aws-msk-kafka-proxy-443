output "bootstrap_server" {
  description = "External Kafka bootstrap endpoint."
  value       = "${local.bootstrap_hostname}:443"
}

output "broker_address_pattern" {
  description = "Client-visible broker address pattern returned in Kafka metadata."
  value       = local.broker_hostname
}

output "nlb_dns_name" {
  description = "AWS-generated NLB DNS name; clients should use the Kafka DNS hostname instead."
  value       = aws_lb.kafka.dns_name
}

output "nlb_zone_id" {
  description = "Canonical hosted zone ID for an external-DNS alias record targeting the NLB."
  value       = aws_lb.kafka.zone_id
}

output "bootstrap_hostname" {
  description = "Hostname callers must point at the NLB when DNS is managed externally."
  value       = local.bootstrap_hostname
}

output "broker_wildcard_hostname" {
  description = "Wildcard hostname callers must point at the NLB when DNS is managed externally."
  value       = "*.${var.kafka_domain}"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.proxy.name
}

output "ecs_service_name" {
  value = aws_ecs_service.proxy.name
}

output "proxy_security_group_id" {
  value = aws_security_group.proxy.id
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name, or null when create_cloudwatch_dashboard is false."
  value       = try(aws_cloudwatch_dashboard.proxy[0].dashboard_name, null)
}

output "alarm_names" {
  description = "CloudWatch alarm names, or an empty list when create_alarms is false."
  value = concat(
    aws_cloudwatch_metric_alarm.proxy_log_errors[*].alarm_name,
    aws_cloudwatch_metric_alarm.unhealthy_targets[*].alarm_name,
    aws_cloudwatch_metric_alarm.low_healthy_targets[*].alarm_name,
    aws_cloudwatch_metric_alarm.high_cpu[*].alarm_name,
  )
}

output "post_deploy_commands" {
  value = <<-EOT
    export BOOTSTRAP_SERVER='${local.bootstrap_hostname}:443'
    export CLIENT_CONFIG='/secure/path/client.properties'
    ./tests/verify-tls.sh
    ./tests/verify-metadata.sh
    ./tests/test-produce-consume.sh
  EOT
}
