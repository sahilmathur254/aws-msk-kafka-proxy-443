# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Release process documentation and checklist (`RELEASE.md`).
- Automated GitHub release workflow triggered on version tags.
- Question/support issue template and issue chooser configuration.
- Stale issue and PR workflow (90-day mark, 14-day close).
- Apache-2.0 licensing, contributor guidance, code of conduct, security policy,
  support policy, and GitHub contribution templates.

## [0.1.0] - Unreleased

### Added

- Terraform module for exposing a private Amazon MSK cluster on TCP 443 via
  Kroxylicious, ECS/Fargate, and a Network Load Balancer.
- Kroxylicious SNI Host Identifies Node gateway with TLS termination and
  Kafka metadata response rewriting.
- NLB with cross-zone load balancing and client IP preservation.
- ECS/Fargate service with multi-AZ placement, CPU/memory autoscaling, and
  rolling deployments.
- Route 53 DNS aliases for bootstrap and wildcard broker hostnames.
- IAM roles scoped to ECS task execution and Secrets Manager read access.
- Security groups for NLB ingress, proxy-to-MSK, and health-check traffic.
- CloudWatch log group, log-derived error metrics, alarms, and an operational
  dashboard.
- Optional Container Insights and ECS Exec support.
- Safety guardrails: reject unrestricted client CIDRs and mutable image tags
  by default.
- Secure runtime injection of wildcard TLS certificate and PKCS#8 private
  key from AWS Secrets Manager.
- Pinned Kroxylicious container image built with a non-root runtime user.
- Complete deployment example (`examples/complete/`).
- Kafka client examples for SASL/SCRAM-SHA-512 over TLS and a Python
  transaction client.
- Validation, deployment, preflight, and TLS secret creation scripts.
- Test suite: TLS verification, metadata rewriting, produce/consume, admin
  operations, consumer groups, transactions, port usage, and proxy failover.
- Architecture, feasibility analysis, security model, ADR, test plan,
  cost/operations, and validation report documentation.
- CI workflows for Terraform validation/linting, secret scanning, and
  infrastructure configuration scanning.
