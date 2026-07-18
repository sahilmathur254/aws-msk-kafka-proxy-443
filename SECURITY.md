# Security Policy

## Reporting a vulnerability

Do not report security vulnerabilities through public GitHub issues,
discussions, pull requests, or commits.

Use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-your-repository)
when it is enabled for this repository. Include a clear description,
reproduction steps, affected versions or files, impact, and any suggested
mitigation. Do not include live credentials, TLS private keys, or customer data.

If private reporting is unavailable, contact the repository owner through their
GitHub profile and request a private reporting channel.

We will acknowledge a report within 7 days, provide a status update within 14
days where possible, and coordinate disclosure after a fix or mitigation is
available. Please allow reasonable time for remediation before public
disclosure.

## Supported versions

| Version | Supported |
| --- | --- |
| Current default branch | Yes |
| Earlier releases | No |

This project is experimental and pre-1.0. It has not yet published a supported
release line or production acceptance evidence.

## Security scope

The security boundary includes the Terraform configuration, helper scripts,
container wrapper, client examples, and documentation in this repository.
Likely high-impact reports include unintended public exposure, insecure TLS
handling, secret disclosure, IAM privilege escalation, security-group bypass,
unsafe defaults, and proxy behavior that routes client traffic outside the
documented boundary.

For deployment-specific incidents, immediately restrict affected security-group
ingress, rotate exposed credentials or certificates, and follow your
organisation's incident-response process.
