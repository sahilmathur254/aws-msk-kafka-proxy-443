# Optional ECR mirror/wrapper image. Terraform can use the upstream digest directly.
# Kroxylicious 0.25.0 declares UID 185 as its supported runtime user. Repeat it
# here so static configuration scanners can verify this wrapper remains non-root.
FROM quay.io/kroxylicious/proxy@sha256:55f639c6a7c479503203c55dc5d5f5b956a2e61dd188b3152b736ca20f648f90

LABEL org.opencontainers.image.title="Kroxylicious MSK port-443 proxy"
LABEL org.opencontainers.image.version="0.25.0"
LABEL org.opencontainers.image.source="https://github.com/kroxylicious/kroxylicious"

USER 185
