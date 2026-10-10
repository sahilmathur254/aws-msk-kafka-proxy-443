# Optional ECR mirror/wrapper image. Terraform can use the upstream digest directly.
# Kroxylicious 0.23.0 declares UID 185 as its supported runtime user. Repeat it
# here so static configuration scanners can verify this wrapper remains non-root.
FROM quay.io/kroxylicious/proxy@sha256:d144aceac0cc8d32e56c368ace052c6f568fbb6353988c1f3e6814aab2d5a117

LABEL org.opencontainers.image.title="Kroxylicious MSK port-443 proxy"
LABEL org.opencontainers.image.version="0.23.0"
LABEL org.opencontainers.image.source="https://github.com/kroxylicious/kroxylicious"

USER 185
