terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "msk_proxy_443" {
  source = "../../terraform"

  name                             = var.name
  vpc_id                           = var.vpc_id
  public_subnet_ids                = var.public_subnet_ids
  private_subnet_ids               = var.private_subnet_ids
  msk_security_group_id            = var.msk_security_group_id
  msk_bootstrap_brokers_sasl_scram = var.msk_bootstrap_brokers_sasl_scram
  route53_zone_id                  = var.route53_zone_id
  kafka_domain                     = var.kafka_domain
  tls_secret_arn                   = var.tls_secret_arn
  client_cidrs                     = var.client_cidrs
  tags                             = var.tags
}

output "bootstrap_server" {
  description = "External Kafka bootstrap endpoint."
  value       = module.msk_proxy_443.bootstrap_server
}
