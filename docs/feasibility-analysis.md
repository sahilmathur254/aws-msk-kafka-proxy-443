# Feasibility analysis

## Decision

The requirement is feasible with a **Kafka protocol-aware proxy** that rewrites broker addresses and exposes broker-specific hostnames on a shared TLS port. It is not feasible with a single generic TCP port-forward alone.

The implementation uses Kroxylicious SNI Host Identifies Node behind an NLB:

- External bootstrap: `bootstrap.<kafka-domain>:443`
- External brokers: `broker-<node-id>.<kafka-domain>:443`
- Internal proxy listener: `9192`
- Private MSK SASL/SCRAM TLS listener: normally `9096`

Only the client-facing leg is constrained to port 443. The private proxy-to-MSK connection uses the MSK-managed listener because external clients never see or reach that leg.

## Why a normal TCP proxy fails

Kafka bootstrap is only discovery. After the first connection, the client obtains cluster metadata containing every broker's advertised hostname and port. It then opens direct TCP connections to the appropriate broker for:

- Partition leaders
- Group coordinators
- Transaction coordinators
- Administrative requests

A load balancer forwarding `public:443` to one MSK bootstrap broker does not alter those Kafka responses. The client would receive private MSK broker addresses such as `b-1...amazonaws.com:9096`, which are inaccessible externally and violate the port-443 requirement.

## What must be rewritten

Kroxylicious presents a virtual cluster and transparently rewrites broker addresses carried by Kafka responses, including:

- `Metadata`
- `DescribeCluster`
- `FindCoordinator`

This is necessary because bootstrap, partition leadership, consumer groups, transactions, and admin operations may all cause clients to discover or select broker-specific endpoints.

## Why broker identity must be preserved

Kafka is not a request/response service where every operation can be sent to any healthy backend. Clients select specific brokers based on metadata. A compliant proxy therefore needs one logical external endpoint for each broker, even when every endpoint resolves to the same NLB.

Kroxylicious encodes the broker node ID in the hostname:

```text
broker-1.kafka.example.com:443
broker-2.kafka.example.com:443
broker-3.kafka.example.com:443
```

The TLS SNI value tells the selected proxy task which MSK broker the connection represents.

## TLS behaviour

There are two independent encrypted sessions:

1. Client → NLB → Kroxylicious
   - The NLB uses a TCP listener and does not terminate TLS.
   - Kroxylicious presents the wildcard certificate.
   - Clients validate the bootstrap or broker hostname.
2. Kroxylicious → MSK
   - Kroxylicious initiates TLS to the native MSK broker hostname.
   - Platform trust validates the AWS-issued MSK certificate.

The proxy therefore has access to Kafka protocol frames, which is required to rewrite metadata. It does not disable TLS verification on either leg.

## SASL/SCRAM behaviour

SASL/SCRAM runs inside the Kafka protocol after downstream TLS is established. With no SASL termination filter configured, Kroxylicious forwards the SASL exchange to MSK. MSK verifies the credentials and remains the authentication authority.

The client password is not stored in the proxy deployment. It remains client-side and is registered with MSK through the normal Amazon MSK Secrets Manager association.

## Is SNI routing alone enough?

No. SNI routing solves the inbound question, “which broker does this hostname represent?” It does not change the private broker addresses contained in Kafka protocol responses. Metadata rewriting and SNI routing are both required.

## DNS and certificate requirements

All client-visible names must resolve to the NLB. A wildcard Route 53 alias is appropriate for broker node IDs that are not known in advance.

For `kafka_domain = kafka.example.com`:

- DNS: `bootstrap.kafka.example.com` → NLB
- DNS: `*.kafka.example.com` → NLB
- Certificate SAN: `*.kafka.example.com`

The bootstrap name deliberately sits below the wildcard domain. A wildcard for `*.kafka.example.com` covers both `bootstrap.kafka.example.com` and `broker-1.kafka.example.com`.

## Options comparison

| Option | All client endpoints on 443 | Metadata rewritten | Broker identity | External clients | Assessment |
|---|---:|---:|---:|---:|---|
| NLB/TCP → one MSK bootstrap address | No | No | No | Initial connection only | Reject |
| NLB → HAProxy/Envoy SNI routing | Potentially | No | Yes inbound only | Yes | Incomplete without protocol-aware rewriting |
| NLB → Kroxylicious SNI gateway | Yes | Yes | Yes | Yes | Selected |
| PrivateLink → Kroxylicious | Yes | Yes | Yes | Only clients with PrivateLink-capable network | Strong private alternative |
| VPN/Direct Connect → Kroxylicious | Yes | Yes | Yes | On-premises/private networks | Preferred when available |

## Availability and scaling

- The NLB spans at least two public subnets/AZs.
- ECS tasks run in private subnets and have desired count `>= 2`.
- NLB cross-zone load balancing is enabled.
- ECS replaces failed tasks and target tracking can add tasks.
- Each Kafka TCP connection remains bound to one proxy task for its lifetime.

Scaling out increases capacity for new connections. It does not migrate existing connections. Kafka client reconnects, rolling connection expiry, or controlled client restarts may be required to redistribute a very stable connection population.

## “Even” traffic across brokers

There are different distributions:

- NLB distributes new TCP flows across healthy proxy targets.
- Kroxylicious routes each broker-specific connection to its identified MSK broker.
- Kafka partition leaders determine where produce/fetch requests go.
- Consumer group assignment determines which consumer reads each partition.

Consequently, equal proxy task counts do not guarantee equal bytes per MSK broker. Partition count, key distribution, leader placement, message sizes, and consumer lag dominate broker traffic balance.

## Feasibility limitations

- A public endpoint cannot be protected by AWS WAF because the payload is Kafka over raw TCP, not HTTP.
- The proxy terminates TLS by design; pure end-to-end client-to-MSK TLS is incompatible with metadata rewriting.
- Certificate rotation requires a new ECS task definition/deployment because certificate values are read from Secrets Manager at task start.
- Direct internet exposure should be replaced with VPN, Direct Connect, or PrivateLink where possible.

## Evidence

- [Kroxylicious Proxy Guide](https://kroxylicious.io/documentation/0.23.0/html/kroxylicious-proxy/) documents virtual-cluster metadata rewriting, SNI Host Identifies Node, TLS configuration, and custom advertised port `443`.
- [Amazon MSK SASL/SCRAM](https://docs.aws.amazon.com/msk/latest/developerguide/msk-password-howitworks.html) requires TLS for SASL/SCRAM.
- [AWS NLB target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html) documents TCP flow behaviour and target health checking.
