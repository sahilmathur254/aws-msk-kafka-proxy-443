#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  create-tls-secret.sh --name NAME --certificate FULLCHAIN_PEM \
    --private-key PKCS8_KEY_PEM --region AWS_REGION [--kms-key-id KEY_ID]

Creates or adds a new version to a Secrets Manager secret containing:
  {"certificate":"...","private_key":"..."}
USAGE
}

secret_name=""
certificate_file=""
private_key_file=""
region=""
kms_key_id=""

while (($#)); do
  case "$1" in
    --name) secret_name=${2:?}; shift 2 ;;
    --certificate) certificate_file=${2:?}; shift 2 ;;
    --private-key) private_key_file=${2:?}; shift 2 ;;
    --region) region=${2:?}; shift 2 ;;
    --kms-key-id) kms_key_id=${2:?}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$secret_name" && -n "$certificate_file" && -n "$private_key_file" && -n "$region" ]] || {
  usage >&2
  exit 2
}

[[ -r "$certificate_file" ]] || { echo "Certificate is not readable: $certificate_file" >&2; exit 1; }
[[ -r "$private_key_file" ]] || { echo "Private key is not readable: $private_key_file" >&2; exit 1; }

grep -q "BEGIN CERTIFICATE" "$certificate_file" || {
  echo "Certificate file does not contain PEM certificate data" >&2
  exit 1
}

grep -q "BEGIN PRIVATE KEY" "$private_key_file" || {
  echo "Private key must be unencrypted PKCS#8 PEM (BEGIN PRIVATE KEY)" >&2
  exit 1
}

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
chmod 600 "$tmpfile"

jq -n \
  --rawfile certificate "$certificate_file" \
  --rawfile private_key "$private_key_file" \
  '{certificate: $certificate, private_key: $private_key}' > "$tmpfile"

if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$region" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --secret-id "$secret_name" \
    --secret-string "file://$tmpfile" \
    --region "$region" \
    --query ARN \
    --output text
else
  args=(
    secretsmanager create-secret
    --name "$secret_name"
    --description "Wildcard TLS certificate for the external MSK Kafka proxy"
    --secret-string "file://$tmpfile"
    --region "$region"
    --query ARN
    --output text
  )
  if [[ -n "$kms_key_id" ]]; then
    args+=(--kms-key-id "$kms_key_id")
  fi
  aws "${args[@]}"
fi
