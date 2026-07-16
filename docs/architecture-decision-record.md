# ADR-001: Protocol-aware SNI proxy for port-443 Kafka access

- **Status:** Accepted for proof of concept
- **Date:** 2026-07-16

## Context

External Kafka clients can make outbound connections only to TCP 443. They must use TLS and SASL/SCRAM for bootstrap, metadata, produce, consume, consumer groups, transactions, and administration. Amazon MSK must remain private.

Kafka clients connect to individual brokers discovered from protocol metadata, so a conventional single-address TCP reverse proxy does not meet the requirement.

## Decision

Deploy Kroxylicious on ECS/Fargate behind an internet-facing NLB TCP listener.

- Use SNI Host Identifies Node.
- Bind Kroxylicious internally on `9192`.
- Advertise every broker hostname with port `443`.
- Use Route 53 bootstrap and wildcard broker aliases.
- Terminate downstream TLS at Kroxylicious.
- Re-establish validated TLS to private MSK SASL/SCRAM brokers.
- Pass the SASL/SCRAM exchange through to MSK.
- Enable NLB client-IP preservation for the public TCP target group.

## Rationale

Kroxylicious natively understands Kafka protocol responses that contain broker addresses. Its SNI gateway preserves broker identity without consuming a port per broker, and its advertised-port override is explicitly intended for a load balancer performing port forwarding.

ECS/Fargate avoids operating worker nodes for the proxy pool. The NLB supplies scalable TCP ingress and multi-AZ target health management.

## Rejected alternatives

### NLB directly to MSK

Rejected because metadata still contains native MSK broker addresses and ports. It also does not provide a stable public per-broker mapping.

### HAProxy or Envoy only

Rejected as the complete solution because SNI routing alone does not rewrite Kafka metadata. Either could form part of a larger design, but would add another layer without replacing the protocol-aware proxy.

### One port per broker

Rejected because external policy permits only port 443 and MSK node IDs/topology may change.

### Public MSK access

Rejected because it exposes brokers directly, does not naturally change all advertised ports to 443, and violates the requirement that MSK remain private.

### EKS operator deployment

Viable but not selected for this standalone proof of concept because it introduces Kubernetes control-plane and operator overhead. It becomes attractive when the organisation already operates EKS and wants topology-spread controls and Kubernetes-native certificate automation.

## Consequences

Positive:

- All client-visible Kafka endpoints use one permitted port.
- Broker identity and Kafka routing semantics are retained.
- MSK remains private.
- The proxy pool scales independently of MSK.
- Authentication and Kafka ACLs remain at MSK.

Negative:

- TLS terminates at the proxy, creating an additional trust boundary.
- The proxy becomes part of the Kafka data plane and must be capacity-tested.
- Certificate rotation requires proxy task replacement.
- Existing long-lived TCP connections do not redistribute automatically after scale-out.
- Public raw TCP cannot use AWS WAF.

## Revisit triggers

Re-evaluate this decision if:

- Clients can use VPN, Direct Connect, or PrivateLink.
- Kroxylicious changes the relevant gateway or metadata-rewrite APIs.
- The organisation adopts EKS as the standard platform.
- Compliance prohibits TLS termination in an intermediary.
- Performance tests show unacceptable proxy latency or throughput.
