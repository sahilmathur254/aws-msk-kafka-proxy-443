# Validation report

Validation date: 2026-07-16

## Passed locally

- All Bash scripts pass `bash -n`.
- All shell scripts pass ShellCheck 0.11.0 with no findings.
- `clients/transactions.py` compiles with Python 3.
- All Terraform files pass `terraform fmt -check -recursive` using Terraform 1.15.8.
- Terraform initialization resolved and locked `hashicorp/aws` 6.55.0.
- The rendered proxy configuration was started with the actual Kroxylicious 0.23.0 binary on Java 21.
- Kroxylicious accepted the configuration, bound its listeners, and exposed the Prometheus metrics endpoint.

## Environment-limited validation

The local sandbox could not complete `terraform validate` because the downloaded AWS provider process could not complete Terraform's plugin handshake in this runtime. Provider installation and HCL parsing succeeded, and the resource arguments were checked against the current official provider documentation, but this does not replace running validation on the deployment workstation.

Run before planning:

```bash
./scripts/validate.sh
terraform -chdir=terraform validate
```

## Requires the target AWS account

The following were not claimed as executed:

- Terraform plan or apply against real VPC, subnet, Route 53, Secrets Manager, ECS, NLB, and MSK resources.
- Public DNS resolution and certificate-chain verification.
- SASL/SCRAM authentication against a real MSK cluster.
- Metadata, produce/consume, admin, group, transaction, and observed-port tests.
- Proxy task, Availability Zone, and MSK broker failure tests.
- Throughput, latency, soak, and autoscaling tests.

Use [test-plan.md](test-plan.md) as the deployment acceptance gate.
