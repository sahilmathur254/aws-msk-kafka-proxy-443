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
  value = aws_cloudwatch_dashboard.proxy.dashboard_name
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
