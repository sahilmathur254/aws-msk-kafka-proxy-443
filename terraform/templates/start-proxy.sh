#!/bin/sh
set -eu

umask 077
runtime_dir=/tmp/kroxylicious-runtime
mkdir -p "$runtime_dir"

: "${KROXY_CONFIG_B64:?KROXY_CONFIG_B64 is required}"
: "${TLS_CERTIFICATE:?TLS_CERTIFICATE is required}"
: "${TLS_PRIVATE_KEY:?TLS_PRIVATE_KEY is required}"

case "$TLS_CERTIFICATE" in
  *"BEGIN CERTIFICATE"*) ;;
  *)
    echo "TLS_CERTIFICATE does not contain a PEM certificate" >&2
    exit 1
    ;;
esac

case "$TLS_PRIVATE_KEY" in
  *"BEGIN PRIVATE KEY"*) ;;
  *)
    echo "TLS_PRIVATE_KEY must be an unencrypted PKCS#8 PEM private key" >&2
    exit 1
    ;;
esac

printf '%s' "$KROXY_CONFIG_B64" | base64 -d > "$runtime_dir/config.yaml"
printf '%s\n' "$TLS_CERTIFICATE" > "$runtime_dir/tls.crt"
printf '%s\n' "$TLS_PRIVATE_KEY" > "$runtime_dir/tls.key"
chmod 600 "$runtime_dir/config.yaml" "$runtime_dir/tls.crt" "$runtime_dir/tls.key"

unset KROXY_CONFIG_B64 TLS_CERTIFICATE TLS_PRIVATE_KEY

exec /opt/kroxylicious/bin/kroxylicious-start.sh \
  --config "$runtime_dir/config.yaml"
