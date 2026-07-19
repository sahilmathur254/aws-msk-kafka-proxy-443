# Release process

This document describes how to cut a versioned release of the MSK proxy module.

## Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html):

- **Major**: breaking changes to Terraform inputs, outputs, or required provider versions.
- **Minor**: new features, new optional variables, or new outputs.
- **Patch**: bug fixes, documentation, and CI changes with no interface impact.

## Release checklist

Before tagging a release, verify the following:

### Validation

- [ ] `./scripts/validate.sh` passes locally.
- [ ] `terraform fmt -check -recursive` reports no drift.
- [ ] `terraform validate` succeeds in `terraform/` and `examples/complete/`.
- [ ] TFLint reports no warnings at the configured severity.
- [ ] CI is green on the branch or commit being tagged.

### Security

- [ ] Trivy configuration scan passes (`HIGH` and `CRITICAL`).
- [ ] Gitleaks secret scan passes.
- [ ] No credentials, private keys, or Terraform state files are committed.
- [ ] Container image tag is pinned to a digest, not a mutable tag.

### Documentation

- [ ] `CHANGELOG.md` contains an entry for the new version with the release date.
- [ ] `README.md` reflects any new or changed variables, outputs, or prerequisites.
- [ ] `examples/complete/` is updated if variables were added or removed.
- [ ] Architecture, security, or ADR docs are updated for significant changes.

### Compatibility

- [ ] `versions.tf` declares the supported Terraform and provider version ranges.
- [ ] Breaking changes are called out in the changelog under a `### Changed` or `### Removed` heading.
- [ ] Upgrade notes are included when migration steps are needed.

## Cutting a release

1. Update `CHANGELOG.md`: move items from `[Unreleased]` into a new version section with today's date.
2. Commit the changelog update to `main`.
3. Tag the commit:

   ```bash
   git tag -a v0.1.0 -m "v0.1.0"
   git push origin v0.1.0
   ```

4. The `release.yml` workflow creates the GitHub release automatically with the changelog body.
5. Verify the release appears at `https://github.com/sahilmathur254/aws-msk-kafka-proxy-443/releases`.

## Terraform Registry

The [Terraform Registry](https://registry.terraform.io/) requires repositories to
follow the `terraform-<PROVIDER>-<NAME>` naming convention. This repository
(`aws-msk-kafka-proxy-443`) does not match that pattern.

To publish on the registry, either:

- Rename the repository to `terraform-aws-msk-kafka-proxy-443`, or
- Create a mirror repository with the required name that tracks releases from this repository.

Until then, consume the module from a Git tag:

```hcl
module "msk_proxy_443" {
  source = "git::https://github.com/sahilmathur254/aws-msk-kafka-proxy-443.git//terraform?ref=v0.1.0"
}
```
