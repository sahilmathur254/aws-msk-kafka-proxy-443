# Optional ECR mirror/wrapper image. Terraform can use the upstream digest directly.
# The upstream image's supported runtime user is verified during the dedicated
# container-hardening work; do not change it blindly in this wrapper.
#trivy:ignore:DS002
FROM quay.io/kroxylicious/proxy@sha256:52cd6fb28212c4310bd06b8af6de766f7e3a7f19fd27b0249f48a0413c4e5358

LABEL org.opencontainers.image.title="Kroxylicious MSK port-443 proxy"
LABEL org.opencontainers.image.version="0.23.0"
LABEL org.opencontainers.image.source="https://github.com/kroxylicious/kroxylicious"
