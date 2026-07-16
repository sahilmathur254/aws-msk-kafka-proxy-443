# Cost and operational trade-offs

## Main cost drivers

This project intentionally does not hard-code price estimates because AWS rates vary by Region and change over time. Use the AWS Pricing Calculator with the target Region and workload.

Include:

- NLB hours and processed Network Load Balancer Capacity Units.
- Two or more Fargate tasks: vCPU, memory, and ephemeral storage.
- Internet data transfer out.
- Cross-AZ data processing where applicable.
- NAT Gateway hours and data processing if tasks pull images or call AWS APIs through NAT.
- Route 53 hosted-zone/query charges.
- Secrets Manager secret and API calls.
- CloudWatch log ingestion/retention, metrics, dashboards, and alarms.
- Optional ECR, VPC endpoints, Flow Logs, Shield Advanced, or PrivateLink.

## Baseline sizing

The Terraform defaults start with two Fargate tasks, each with 1 vCPU and 2 GiB memory. This is only a safe functional baseline. Kafka proxy sizing depends on:

- Concurrent broker connections
- Produce/fetch throughput
- Message size and compression
- TLS handshake rate
- Kafka API mix
- GC behaviour
- Number of virtual brokers and clients

Use load tests to set CPU, memory, task count, and autoscaling thresholds.

## Public NLB versus private connectivity

| Model | Relative operational effort | Exposure | Typical additional cost |
|---|---|---|---|
| Public NLB | Lowest initial effort | Public allow-listed TCP endpoint | Internet transfer, NAT |
| Site-to-Site VPN | Moderate | Private tunnel | VPN hourly/data processing |
| Direct Connect | High setup | Private dedicated path | Port/circuit/data transfer |
| PrivateLink | Moderate per consumer | Private endpoint service | Endpoint hours/data processing |

## Runbook priorities

1. Monitor healthy target count and active flows.
2. Alert on proxy log errors and ECS task churn.
3. Test certificate expiry/rotation well before expiry.
4. Review source CIDRs and SCRAM principals.
5. Track proxy-to-broker traffic by node ID.
6. Validate client retry/backoff settings.
7. Perform controlled proxy and broker failure tests.
8. Patch the pinned image only after release-note and compatibility review.

## Upgrade strategy

1. Read Kroxylicious release notes and configuration deprecations.
2. Pin the new image digest in a branch.
3. Run local/static validation.
4. Deploy to a non-production environment.
5. Execute the full acceptance matrix and a load test.
6. Apply to production with ECS rolling deployment controls.
7. Retain the previous digest for immediate rollback.

## Capacity caveat

Adding proxy tasks does not redistribute existing long-lived Kafka TCP flows. Scale ahead of known peaks. If connection imbalance is material, use controlled client reconnects or a reviewed connection-expiration policy rather than abrupt termination.
