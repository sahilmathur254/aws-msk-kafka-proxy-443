# Amazon MSK proxy on port 443

This project exposes a **private Amazon MSK cluster** to external Kafka clients while ensuring every client-visible Kafka connection uses **TCP 443**.

> **Status: Experimental / pre-1.0.** Validate with a non-production MSK cluster before production use.

The selected design is:

- An internet-facing AWS Network Load Balancer (NLB) accepts raw TCP/TLS on `443`.
- The NLB forwards the unchanged TLS stream to a multi-AZ Kroxylicious pool on internal port `9192`.
- Kroxylicious terminates downstream TLS, routes by SNI, and rewrites Kafka `Metadata`, `DescribeCluster`, and `FindCoordinator` responses.
- Client-visible brokers are advertised as `broker-<node-id>.<kafka-domain>:443`.
- Kroxylicious opens a separate TLS connection to private MSK brokers on the internal SASL/SCRAM TLS listener, normally `9096`.
- SASL/SCRAM is passed through at the Kafka protocol layer, so MSK remains the authentication authority.

The native MSK broker hostnames and ports never need to be reachable by external clients.

> This is a production-oriented proof of concept, not a claim that deployment is safe without organisation-specific review. Test it with a non-production MSK cluster first.

## What is included

- Terraform for the NLB, security groups, ECS/Fargate, Route 53, IAM, autoscaling, logs, alarms, and a dashboard.
- A pinned Kroxylicious container image.
- Secure runtime injection of a wildcard TLS certificate and PKCS#8 private key from AWS Secrets Manager.
- Kafka client examples using SASL/SCRAM-SHA-512 and TLS hostname verification.
- Metadata, port-use, produce/consume, admin, consumer-group, transaction, and failover tests.
- Architecture, feasibility, security, ADR, test-plan, and cost/operations documents.
- A validation report separating completed local checks from AWS-dependent acceptance tests.

## Use as a Terraform module

The reusable module is in [`terraform/`](terraform). The
[`examples/complete`](examples/complete) configuration is the deployable local
reference. The caller owns AWS provider configuration, credentials, backends,
and provider-level tags.

Until a tagged Terraform Registry release exists, consume a reviewed Git tag or
commit explicitly:

```hcl
module "msk_proxy_443" {
  source = "git::https://github.com/sahilmathur254/aws-msk-kafka-proxy-443.git//terraform?ref=<reviewed-tag-or-commit>"

  name                             = "production-msk-proxy"
  vpc_id                           = module.vpc.vpc_id
  public_subnet_ids                = module.vpc.public_subnets
  private_subnet_ids               = module.vpc.private_subnets
  msk_security_group_id            = aws_security_group.msk.id
  msk_bootstrap_brokers_sasl_scram = aws_msk_cluster.main.bootstrap_brokers_sasl_scram
  route53_zone_id                  = data.aws_route53_zone.main.zone_id
  kafka_domain                     = "kafka.example.com"
  tls_secret_arn                   = aws_secretsmanager_secret.kafka_tls.arn
  client_cidrs                     = ["203.0.113.10/32"]
}
```

The module is self-contained: its Kroxylicious configuration and startup script
are packaged under `terraform/templates/`, not loaded from paths outside the
module.

## Important feasibility result

A normal TCP proxy that forwards `443` to an MSK bootstrap address is **not sufficient**. Kafka metadata directs the client to individual brokers. Without protocol-aware rewriting, clients receive private MSK hostnames and native broker ports.

Kroxylicious solves that issue by presenting a virtual Kafka cluster, maintaining a broker-specific endpoint for every MSK node, and rewriting broker addresses in protocol responses. Its SNI Host Identifies Node gateway allows all those endpoints to share one port.

See [docs/feasibility-analysis.md](docs/feasibility-analysis.md) for the detailed reasoning.

## Prerequisites

You need:

1. Terraform `>= 1.6`.
2. AWS CLI v2 authenticated to the target account.
3. An existing Amazon MSK provisioned cluster with:
   - SASL/SCRAM enabled.
   - TLS client-to-broker encryption enabled.
   - Public access disabled.
4. The MSK SASL/SCRAM bootstrap string returned as `BootstrapBrokerStringSaslScram`.
5. Public subnets for the internet-facing NLB in at least two Availability Zones.
6. Private subnets for ECS tasks in at least two Availability Zones.
7. NAT access from the private subnets, or suitable VPC endpoints plus an ECR mirror of the proxy image.
8. A Route 53 public hosted zone containing the chosen Kafka subdomain.
9. A publicly trusted wildcard certificate covering `*.<kafka-domain>` and its unencrypted PKCS#8 private key.
10. At least one restricted external client CIDR. Avoid `0.0.0.0/0` outside a disposable proof of concept.

### DNS and certificate example

If `kafka_domain = "kafka.example.com"`, clients use:

- `bootstrap.kafka.example.com:443`
- `broker-1.kafka.example.com:443`
- `broker-2.kafka.example.com:443`

The certificate must cover `*.kafka.example.com`. The project creates Route 53 aliases for `bootstrap.kafka.example.com` and `*.kafka.example.com`, both pointing to the NLB.

## 1. Create the TLS secret

The secret must contain JSON with `certificate` and `private_key` fields. The certificate should contain the leaf certificate followed by intermediates. The private key must be unencrypted PKCS#8 PEM.

```bash
./scripts/create-tls-secret.sh \
  --name kafka-proxy/wildcard-tls \
  --certificate /secure/path/fullchain.pem \
  --private-key /secure/path/private-key.pkcs8.pem \
  --region eu-west-1
```

The script prints the secret ARN. It does not copy the certificate into this repository.

## 2. Configure Terraform

```bash
cp examples/complete/terraform.tfvars.example examples/complete/terraform.tfvars
```

Edit all placeholder values. The most important variables are:

- `vpc_id`
- `public_subnet_ids`
- `private_subnet_ids`
- `msk_security_group_id`
- `msk_bootstrap_brokers_sasl_scram`
- `route53_zone_id`
- `kafka_domain`
- `tls_secret_arn`
- `client_cidrs`

The module rejects `0.0.0.0/0` client access and mutable container image tags
by default. The `allow_unrestricted_client_cidrs` and
`allow_mutable_image_tag` escape hatches require an explicit configuration
change and should be used only after a documented risk decision.

### External DNS and optional monitoring

Set `create_dns_records = false` when another DNS provider manages the Kafka
hostnames. Create alias or CNAME-equivalent records for the `bootstrap_hostname`
and `broker_wildcard_hostname` outputs, both targeting `nlb_dns_name`; use
`nlb_zone_id` where the DNS provider requires the NLB's canonical hosted-zone
ID. `route53_zone_id` is then not required.

`create_alarms`, `create_cloudwatch_dashboard`, `enable_container_insights`,
and `enable_execute_command` all default to safe operational settings and can
be configured independently.

## 3. Validate and deploy

```bash
./scripts/validate.sh
terraform -chdir=examples/complete init
terraform -chdir=examples/complete plan -out=tfplan
terraform -chdir=examples/complete apply tfplan
```

The output `bootstrap_server` is the only bootstrap address external clients need.

## 4. Configure a Kafka test client

Install Apache Kafka CLI tools, `kcat`, `jq`, and OpenSSL. Then create a local client properties file:

```bash
cp clients/client.properties.example /secure/path/client.properties
cp clients/kcat.properties.example /secure/path/kcat.properties
chmod 600 /secure/path/client.properties
chmod 600 /secure/path/kcat.properties
```

Replace the username and password placeholders. Do not commit that file.

Set the test environment:

```bash
export BOOTSTRAP_SERVER="bootstrap.kafka.example.com:443"
export CLIENT_CONFIG="/secure/path/client.properties"
export KCAT_CONFIG="/secure/path/kcat.properties"
export KAFKA_DOMAIN="kafka.example.com"
export TEST_TOPIC="proxy-443-smoke"
```

## 5. Run validation

```bash
./tests/verify-tls.sh
./tests/verify-metadata.sh
./tests/test-produce-consume.sh
./tests/test-admin-operations.sh
./tests/test-consumer-group.sh
./tests/test-transactions.sh
```

On a Linux client with `sudo`, verify observed destination ports during a real Kafka operation:

```bash
./tests/verify-port-usage.sh
```

For ECS task failure testing:

```bash
export AWS_REGION="eu-west-1"
export ECS_CLUSTER="msk-proxy-443"
export ECS_SERVICE="msk-proxy-443"
export CONFIRM_STOP_TASK="yes"
./tests/test-proxy-failover.sh
```

The test deliberately stops one running ECS task. ECS replaces it automatically.

## Client configuration

Clients must use the proxy hostname and retain TLS hostname verification:

```properties
bootstrap.servers=bootstrap.kafka.example.com:443
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="..." password="...";
ssl.endpoint.identification.algorithm=https
```

The proxy terminates downstream TLS and starts a separate validated TLS session to MSK. SASL/SCRAM Kafka frames pass through the proxy to MSK; the proxy does not authenticate the password itself.

## Operations

- The NLB target group preserves the original client IP for public TCP traffic. This is compatible with Fargate IP targets; validate the behaviour again if the entry point is changed to PrivateLink.
- ECS runs at least two tasks and can scale on CPU and memory.
- NLB cross-zone load balancing is enabled.
- Kroxylicious exposes Prometheus metrics on private port `9190`; this endpoint is used for target health checks and is not exposed publicly.
- CloudWatch contains ECS/NLB infrastructure metrics, application logs, log-derived error metrics, alarms, and a dashboard.
- Kafka traffic distribution follows partition leadership and consumer assignment. An NLB can balance new TCP connections across proxy tasks, but cannot guarantee equal Kafka bytes across brokers.

## Rollback and cleanup

To roll back an application version, set `kroxylicious_image` to the previous pinned digest and apply Terraform. ECS performs a rolling deployment.

To remove the proof of concept:

```bash
terraform -chdir=examples/complete destroy
```

The externally managed TLS secret, MSK cluster, hosted zone, and client credentials are not destroyed. Terraform removes only the ingress rule it created on the existing MSK security group.

## Known boundaries

- This project does not create or modify MSK authentication secrets.
- It does not create the MSK cluster, VPC, subnets, NAT gateways, or public certificate.
- AWS WAF cannot inspect arbitrary Kafka TCP traffic behind an NLB.
- A public TCP endpoint is still an attack surface. Restrict source CIDRs and prefer VPN, Direct Connect, or PrivateLink when the client environment permits it.
- Long-lived Kafka connections do not redistribute immediately when new proxy tasks are added. Client reconnects and connection lifecycle determine rebalancing.
- Run performance, soak, upgrade, certificate-rotation, and disaster-recovery tests before production use.

## References

- [Kroxylicious Proxy Guide](https://kroxylicious.io/documentation/0.23.0/html/kroxylicious-proxy/)
- [Kroxylicious 0.23.0 download and image digest](https://kroxylicious.io/download/0.23.0/)
- [Amazon MSK SASL/SCRAM authentication](https://docs.aws.amazon.com/msk/latest/developerguide/msk-password.html)
- [AWS NLB target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html)
- [AWS NLB security groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-security-groups.html)
- [Network Load Balancers with Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/nlb.html)
