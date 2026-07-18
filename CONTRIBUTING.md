# Contributing

Thanks for contributing to AWS MSK Kafka Proxy on Port 443. This project is
experimental infrastructure for a security-sensitive Kafka data path, so small,
well-tested changes are preferred.

## Before opening an issue

- Search existing issues and documentation first.
- Do not include AWS account IDs, client credentials, TLS private keys, broker
  addresses, or unredacted Terraform state in an issue.
- Report suspected vulnerabilities privately as described in [SECURITY.md](SECURITY.md),
  not through a public issue.

## Development workflow

1. Fork the repository and create a focused branch.
2. Keep unrelated formatting and dependency changes out of the pull request.
3. Run the static validation suite:

   ```bash
   ./scripts/validate.sh
   ```

4. Update documentation, examples, and tests when a public interface or
   operational behaviour changes.
5. Open a pull request using the provided template.

Static validation must not require AWS credentials. Do not run destructive AWS
tests against an account, cluster, or service you do not control.

## Terraform changes

- Preserve backwards compatibility for inputs and outputs where practical.
- Add variable validation for safety-sensitive inputs.
- Keep TLS private keys and Kafka credentials out of Terraform state, outputs,
  examples, logs, and test fixtures.
- Use immutable container image digests unless a documented exception applies.
- Run `terraform fmt -recursive` and `terraform validate` before submitting.

## Testing expectations

Run the relevant local checks and state what you ran in the pull request.
AWS-dependent acceptance tests are optional for normal contributions; when they
are run, document the environment and redact all sensitive identifiers.

## Contributor licence

By submitting a contribution, you agree that it is licensed under the
[Apache License 2.0](LICENSE).
