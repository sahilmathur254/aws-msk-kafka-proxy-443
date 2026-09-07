# Optional ECR mirror/wrapper image. Terraform can use the upstream digest directly.
# Kroxylicious 0.23.0 declares UID 185 as its supported runtime user. Repeat it
# here so static configuration scanners can verify this wrapper remains non-root.
FROM quay.io/kroxylicious/proxy@sha256:6dc155a99911057fe10c6bfbb25fb1660a7cd5e1d4e1a2c73bd7dd82ef5babe5

LABEL org.opencontainers.image.title="Kroxylicious MSK port-443 proxy"
LABEL org.opencontainers.image.version="0.23.0"
LABEL org.opencontainers.image.source="https://github.com/kroxylicious/kroxylicious"

USER 185
