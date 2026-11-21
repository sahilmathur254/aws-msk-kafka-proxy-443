# Optional ECR mirror/wrapper image. Terraform can use the upstream digest directly.
# Kroxylicious 0.25.1 declares UID 185 as its supported runtime user. Repeat it
# here so static configuration scanners can verify this wrapper remains non-root.
FROM quay.io/kroxylicious/proxy@sha256:14be57d38ff0abb8835e410e9b5b788ee3cacf393035e45c7406657c73040e18

LABEL org.opencontainers.image.title="Kroxylicious MSK port-443 proxy"
LABEL org.opencontainers.image.version="0.25.1"
LABEL org.opencontainers.image.source="https://github.com/kroxylicious/kroxylicious"

USER 185
