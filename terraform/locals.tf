locals {
  bootstrap_hostname = "${var.bootstrap_label}.${var.kafka_domain}"
  broker_hostname    = "${var.broker_label_prefix}-$(nodeId).${var.kafka_domain}:443"
  proxy_port         = 9192
  management_port    = 9190
  container_name     = "kroxylicious"

  proxy_config = templatefile("${path.module}/../proxy/config/kroxylicious.yaml.tftpl", {
    virtual_cluster_name = var.name
    msk_bootstrap        = var.msk_bootstrap_brokers_sasl_scram
    bootstrap_hostname   = local.bootstrap_hostname
    broker_hostname      = local.broker_hostname
    proxy_port           = local.proxy_port
    management_port      = local.management_port
    proxy_worker_threads = var.proxy_worker_threads
  })

  startup_script = file("${path.module}/../proxy/scripts/start-proxy.sh")

  common_tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
