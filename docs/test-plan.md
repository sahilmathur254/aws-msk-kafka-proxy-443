# Test plan

## Test principles

A passing TCP connection to the bootstrap hostname is not sufficient. The acceptance suite must prove metadata correctness, TLS verification, SASL authentication, functional Kafka APIs, failure recovery, and observed port use.

## Test environment

- Non-production MSK cluster with at least three brokers where possible.
- Test SCRAM principal with limited topic/group ACLs.
- External Linux host whose route does not provide direct VPC access.
- Apache Kafka CLI tools, `kcat`, `jq`, OpenSSL, AWS CLI, and `tcpdump`.
- A unique test topic with at least six partitions and replication factor appropriate to the cluster.

## Acceptance matrix

| ID | Test | Command | Pass condition |
|---|---|---|---|
| TLS-01 | Bootstrap TLS and hostname | `tests/verify-tls.sh` | Trusted chain and hostname verification succeed |
| META-01 | Metadata addresses | `tests/verify-metadata.sh` | Every broker hostname matches the external pattern and every port is 443 |
| META-02 | No native MSK addresses | `tests/verify-metadata.sh` | No `.amazonaws.com` broker address appears |
| AUTH-01 | SCRAM authentication | Any functional test | Valid client succeeds; invalid password fails |
| DATA-01 | Produce and consume | `tests/test-produce-consume.sh` | Produced unique record is consumed unchanged |
| ADMIN-01 | Topic admin | `tests/test-admin-operations.sh` | Create, describe, alter/config query, and delete operations succeed as permitted |
| GROUP-01 | Consumer group | `tests/test-consumer-group.sh` | Group commits an offset and can be described |
| TXN-01 | Transaction | `tests/test-transactions.sh` | Committed record is visible to read-committed consumer |
| PORT-01 | Observed port use | `tests/verify-port-usage.sh` | All TCP destinations for resolved proxy IPs are port 443 |
| FAIL-01 | Proxy task failure | `tests/test-proxy-failover.sh` | Client retries and service remains available while ECS replaces task |
| FAIL-02 | AZ failure | Manual game day | New connections succeed through remaining AZ; documented recovery time met |
| FAIL-03 | Broker restart | Managed MSK maintenance/test | Clients rediscover leaders and recover without non-443 endpoints |
| SCALE-01 | Scale out/in | ECS desired count change | New flows reach healthy tasks; no unacceptable error spike |
| ROTATE-01 | Certificate rotation | Secret update + forced deployment | New tasks serve new certificate with no invalid chain/hostname errors |

## Negative tests

1. Use an incorrect SCRAM password; expect authentication failure.
2. Connect by NLB hostname rather than the Kafka DNS hostname; expect TLS hostname verification failure.
3. Attempt to connect directly to a task IP from another VPC workload; expect the proxy SG to reject it because only the NLB SG is allowed.
4. Attempt to reach MSK 9096 from the external client; expect network failure.
5. Attempt port 9092/9094/9096/9098 on the public DNS names; expect connection failure.
6. Remove the client source CIDR temporarily in a controlled environment; expect the NLB SG to block new connections.

## Failure-test cautions

`test-proxy-failover.sh` stops an ECS task and therefore changes live state. Run it only against the intended proof-of-concept service. Verify the cluster and service names before execution.

Existing connections assigned to the stopped task will fail and reconnect. Connections assigned to other tasks continue. “No single point of failure” means the service remains available, not that every individual TCP connection survives process termination.

## Performance and soak tests

Before production:

- Measure p50/p95/p99 produce and fetch latency with and without the proxy.
- Test expected and 2× peak connection counts.
- Test message-size and compression combinations used in production.
- Soak for at least one representative business cycle.
- Monitor proxy CPU, heap, GC, active connections, errors, disconnect causes, and upstream broker distribution.
- Confirm NLB active/new flow counts and port allocation behaviour.
- Validate autoscaling does not oscillate.

## Evidence capture

For every executed test retain:

- Timestamp and environment identifier
- Exact command and client version
- Redacted output
- Relevant CloudWatch logs/metrics
- Pass/fail decision
- Recovery time for fault tests
- Any deviation from this project configuration
