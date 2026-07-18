locals {
  aws_region         = data.aws_region.current.region
  bootstrap_hostname = "${var.bootstrap_label}.${var.kafka_domain}"
  broker_hostname    = "${var.broker_label_prefix}-$(nodeId).${var.kafka_domain}:443"
  proxy_port         = 9192
  management_port    = 9190
  container_name     = "kroxylicious"

  proxy_config = templatefile("${path.module}/templates/kroxylicious.yaml.tftpl", {
    virtual_cluster_name = var.name
    msk_bootstrap        = var.msk_bootstrap_brokers_sasl_scram
    bootstrap_hostname   = local.bootstrap_hostname
    broker_hostname      = local.broker_hostname
    proxy_port           = local.proxy_port
    management_port      = local.management_port
    proxy_worker_threads = var.proxy_worker_threads
  })

  startup_script = file("${path.module}/templates/start-proxy.sh")

  fargate_memory_by_cpu = {
    "256"   = [512, 1024, 2048]
    "512"   = [1024, 2048, 3072, 4096]
    "1024"  = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
    "2048"  = [4096, 5120, 6144, 7168, 8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384]
    "4096"  = [8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384, 17408, 18432, 19456, 20480, 21504, 22528, 23552, 24576, 25600, 26624, 27648, 28672, 29696, 30720]
    "8192"  = [16384, 20480, 24576, 28672, 32768, 36864, 40960, 45056, 49152, 53248, 57344, 61440]
    "16384" = [32768, 40960, 49152, 57344, 65536, 73728, 81920, 90112, 98304, 106496, 114688, 122880]
  }

  common_tags = merge(
    {
      Name      = var.name
      Project   = var.name
      ManagedBy = "Terraform"
      Component = "msk-kafka-proxy-443"
    },
    var.tags
  )
}
