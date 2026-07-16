variable "aws_region" {
  description = "AWS Region containing the VPC, ECS service, and MSK cluster."
  type        = string
}

variable "name" {
  description = "Short resource-name prefix."
  type        = string
  default     = "msk-proxy-443"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.name))
    error_message = "name must be 3-24 lowercase letters, digits, or hyphens and start with a letter."
  }
}

variable "vpc_id" {
  description = "Existing VPC containing the private MSK cluster."
  type        = string
}

variable "public_subnet_ids" {
  description = "At least two public subnet IDs in distinct AZs for the internet-facing NLB."
  type        = list(string)

  validation {
    condition     = length(distinct(var.public_subnet_ids)) >= 2
    error_message = "Provide at least two distinct public subnet IDs."
  }
}

variable "private_subnet_ids" {
  description = "At least two private subnet IDs in distinct AZs for ECS/Fargate tasks."
  type        = list(string)

  validation {
    condition     = length(distinct(var.private_subnet_ids)) >= 2
    error_message = "Provide at least two distinct private subnet IDs."
  }
}

variable "msk_security_group_id" {
  description = "Security group attached to the existing MSK brokers."
  type        = string
}

variable "manage_msk_security_group_ingress" {
  description = "Whether Terraform should add an MSK SG ingress rule from the proxy SG on msk_broker_port."
  type        = bool
  default     = true
}

variable "msk_bootstrap_brokers_sasl_scram" {
  description = "Private BootstrapBrokerStringSaslScram value returned by aws kafka get-bootstrap-brokers."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.msk_bootstrap_brokers_sasl_scram)) > 0 && !can(regex("[[:space:]]", var.msk_bootstrap_brokers_sasl_scram))
    error_message = "Provide a non-empty comma-separated MSK SASL/SCRAM bootstrap string without whitespace."
  }
}

variable "msk_broker_port" {
  description = "Private MSK SASL/SCRAM TLS listener port. Standard in-VPC MSK SASL/SCRAM uses 9096."
  type        = number
  default     = 9096

  validation {
    condition     = var.msk_broker_port >= 1 && var.msk_broker_port <= 65535
    error_message = "msk_broker_port must be a valid TCP port."
  }
}

variable "route53_zone_id" {
  description = "Existing public Route 53 hosted-zone ID containing kafka_domain."
  type        = string
}

variable "kafka_domain" {
  description = "Dedicated external Kafka subdomain, for example kafka.example.com."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$", var.kafka_domain))
    error_message = "kafka_domain must be a lowercase fully qualified domain name without a trailing dot."
  }
}

variable "bootstrap_label" {
  description = "Left-most DNS label for the bootstrap endpoint."
  type        = string
  default     = "bootstrap"
}

variable "broker_label_prefix" {
  description = "Prefix used to generate broker-<node-id> hostnames."
  type        = string
  default     = "broker"
}

variable "tls_secret_arn" {
  description = "Secrets Manager ARN containing JSON keys certificate and private_key."
  type        = string
  sensitive   = true
}

variable "tls_secret_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN encrypting the TLS secret."
  type        = string
  default     = null
}

variable "client_cidrs" {
  description = "External IPv4 CIDRs allowed to reach NLB TCP 443. Use narrow organisation/client ranges."
  type        = set(string)

  validation {
    condition     = length(var.client_cidrs) > 0 && alltrue([for cidr in var.client_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Provide at least one valid IPv4 client CIDR."
  }
}

variable "kroxylicious_image" {
  description = "Immutable Kroxylicious image reference."
  type        = string
  default     = "quay.io/kroxylicious/proxy@sha256:52cd6fb28212c4310bd06b8af6de766f7e3a7f19fd27b0249f48a0413c4e5358"
}

variable "proxy_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 1024
}

variable "proxy_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 2048
}

variable "proxy_worker_threads" {
  description = "Kroxylicious Netty worker thread count."
  type        = number
  default     = 8
}

variable "desired_count" {
  description = "Initial ECS task count."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 2
    error_message = "desired_count must be at least 2 for high availability."
  }
}

variable "autoscaling_min_capacity" {
  description = "Minimum ECS task count."
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum ECS task count."
  type        = number
  default     = 10
}

variable "cpu_target_percent" {
  description = "Target ECS average CPU utilisation."
  type        = number
  default     = 60
}

variable "memory_target_percent" {
  description = "Target ECS average memory utilisation."
  type        = number
  default     = 70
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 30
}

variable "nlb_deletion_protection" {
  description = "Enable NLB deletion protection. Set true for production after initial validation."
  type        = bool
  default     = false
}

variable "alarm_action_arns" {
  description = "Optional SNS topic or other alarm action ARNs."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
