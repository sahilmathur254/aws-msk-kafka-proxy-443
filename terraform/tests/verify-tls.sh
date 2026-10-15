#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_command openssl
require_env BOOTSTRAP_SERVER

host=${BOOTSTRAP_SERVER%:*}
port=${BOOTSTRAP_SERVER##*:}

[[ "$port" == "443" ]] || {
  echo "FAIL: BOOTSTRAP_SERVER must use port 443, got $BOOTSTRAP_SERVER" >&2
  exit 1
}

output=$(openssl s_client \
  -connect "$BOOTSTRAP_SERVER" \
  -servername "$host" \
  -verify_hostname "$host" \
  -verify_return_error </dev/null 2>&1) || {
    printf '%s\n' "$output" >&2
    echo "FAIL: TLS chain or hostname verification failed" >&2
    exit 1
  }

printf '%s\n' "$output" | grep -q "Verify return code: 0 (ok)" || {
  printf '%s\n' "$output" >&2
  echo "FAIL: OpenSSL did not report a successful verification" >&2
  exit 1
}

echo "PASS: TLS chain and hostname verification succeeded for $BOOTSTRAP_SERVER"
