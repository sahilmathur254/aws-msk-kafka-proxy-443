# Security model

## Trust boundaries

1. **Untrusted external network:** clients reach only the NLB listener on TCP 443.
2. **Proxy ingress boundary:** NLB forwards traffic only to ECS task port 9192.
3. **Proxy process boundary:** Kroxylicious terminates downstream TLS and reads Kafka protocol frames.
4. **MSK boundary:** MSK authenticates SASL/SCRAM credentials and enforces Kafka ACLs.
5. **AWS control plane:** ECS task startup retrieves certificate material from Secrets Manager.

## Threats and controls

| Threat | Control |
|---|---|
| Direct access to MSK | Public access disabled; MSK SG permits 9096 only from proxy SG |
| Direct access to ECS tasks | Private subnets, no public IP, SG accepts proxy port only from NLB SG |
| Unrestricted internet scanning | `client_cidrs` allow-list on the NLB SG |
| Direct task bypass | Proxy tasks are private and their SG accepts the Kafka listener only from the NLB SG |
| TLS interception or hostname mismatch | Publicly trusted wildcard certificate and client endpoint verification enabled |
| Proxy-to-MSK MITM | Upstream TLS validation uses platform trust; `insecure` is never configured |
| Credential leakage in code | Client credentials remain client-side; TLS key comes from Secrets Manager at task start |
| Secret leakage in logs | Startup script never prints secret values; frame/network debug logging disabled |
| Image drift | Kroxylicious image is pinned by immutable digest |
| Failed target receiving traffic | NLB HTTP health check on private management endpoint |
| Excessive connection attempts | Restricted CIDRs, NLB metrics/alarms, Kafka authentication, optional upstream firewall controls |
| Compromised proxy task | Minimal task role, no MSK secret access, restricted SG egress, ephemeral runtime certificate files |

## TLS certificate handling

The ECS execution role may read only the configured Secrets Manager secret. ECS injects two JSON fields as environment values during task startup. The startup script writes them with `umask 077` into the task's ephemeral filesystem, unsets the environment variables, and starts Kroxylicious.

The private key must be:

- PKCS#8 PEM
- Unencrypted for this implementation
- Paired with a certificate covering the bootstrap and broker wildcard names

For stronger key isolation, replace file-based TLS termination with a reviewed integration that supports HSM-backed keys or terminate TLS in an approved load-balancing tier while securely conveying broker identity. Confirm that any alternative still permits protocol-aware metadata rewriting.

## SASL/SCRAM credentials

The proxy does not retrieve the Amazon MSK SCRAM secret. Each Kafka client supplies its own username and password over the encrypted downstream session. Kroxylicious forwards the SASL exchange to MSK over a separate encrypted upstream session.

Use Kafka ACLs to restrict each principal. Rotate credentials using the normal MSK-associated Secrets Manager process and update clients independently.

## Network egress

The proxy SG permits:

- TCP 9096 to the MSK security group.
- TCP 443 for AWS APIs and, when using the default Quay image, container image retrieval through NAT.

For a hardened production deployment:

1. Mirror the pinned image into private ECR.
2. Add interface endpoints for ECR API, ECR Docker, CloudWatch Logs, and Secrets Manager, plus the S3 gateway endpoint required by ECR.
3. Replace broad HTTPS egress with endpoint-specific rules where supported.
4. Add VPC Flow Logs and central log retention.

## DDoS and application protection

AWS Shield Standard applies to supported AWS edge/network resources by default, but it is not an application-aware Kafka control. AWS WAF cannot inspect arbitrary Kafka TCP traffic behind an NLB.

Compensating controls include:

- Strict source CIDR allow-listing.
- Private connectivity instead of the public internet.
- NLB and connection-count alarms.
- Kafka authentication and ACLs.
- Capacity limits and autoscaling.
- Separate clusters or proxy endpoints for different trust zones.
- Incident procedures for changing SG rules and rotating credentials.

## Secret and certificate rotation

Secrets injected by ECS are read only when a task starts. After updating the TLS secret, force a new ECS deployment:

```bash
aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --force-new-deployment
```

Keep an overlap period where both old and new certificate chains are trusted. Validate the new secret in a non-production task before replacing all tasks.

## Audit recommendations

- Retain CloudTrail management events for ECS, ELB, Route 53, IAM, Secrets Manager, and security groups.
- Enable MSK broker logs appropriate to the cluster.
- Enable VPC Flow Logs for the proxy subnets.
- Review public CIDRs on a fixed schedule.
- Alert on SG changes, task-definition changes, and secret access anomalies.
- Do not enable Kroxylicious frame logging in production unless payload exposure has been assessed.
