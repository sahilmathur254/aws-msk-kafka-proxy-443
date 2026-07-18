variable "aws_region" {
  description = "AWS Region containing the VPC, ECS service, and MSK cluster."
  type        = string
}

variable "name" {
  description = "Short resource-name prefix."
  type        = string
  default     = "msk-proxy-443"
}

variable "vpc_id" {
  description = "Existing VPC containing the private MSK cluster."
  type        = string
}

variable "public_subnet_ids" {
  description = "At least two public subnet IDs for the internet-facing NLB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "At least two private subnet IDs for ECS/Fargate tasks."
  type        = list(string)
}

variable "msk_security_group_id" {
  description = "Security group attached to the existing MSK brokers."
  type        = string
}

variable "msk_bootstrap_brokers_sasl_scram" {
  description = "Private MSK SASL/SCRAM bootstrap brokers."
  type        = string
  sensitive   = true
}

variable "route53_zone_id" {
  description = "Existing public Route 53 hosted-zone ID containing kafka_domain."
  type        = string
}

variable "kafka_domain" {
  description = "Dedicated external Kafka subdomain."
  type        = string
}

variable "tls_secret_arn" {
  description = "Secrets Manager ARN containing certificate and private_key JSON fields."
  type        = string
  sensitive   = true
}

variable "client_cidrs" {
  description = "External IPv4 CIDRs permitted to reach the NLB."
  type        = set(string)
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
