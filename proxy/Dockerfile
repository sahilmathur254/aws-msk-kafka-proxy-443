# Optional ECR mirror/wrapper image. Terraform can use the upstream digest directly.
# Kroxylicious 0.23.0 declares UID 185 as its supported runtime user. Repeat it
# here so static configuration scanners can verify this wrapper remains non-root.
FROM quay.io/kroxylicious/proxy@sha256:52cd6fb28212c4310bd06b8af6de766f7e3a7f19fd27b0249f48a0413c4e5358

LABEL org.opencontainers.image.title="Kroxylicious MSK port-443 proxy"
LABEL org.opencontainers.image.version="0.23.0"
LABEL org.opencontainers.image.source="https://github.com/kroxylicious/kroxylicious"

USER 185
