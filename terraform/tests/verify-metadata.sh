#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_command kcat
require_command jq
require_env BOOTSTRAP_SERVER
require_env KCAT_CONFIG
require_env KAFKA_DOMAIN

[[ -r "$KCAT_CONFIG" ]] || { echo "KCAT_CONFIG is not readable: $KCAT_CONFIG" >&2; exit 1; }
[[ "${BOOTSTRAP_SERVER##*:}" == "443" ]] || {
  echo "FAIL: bootstrap endpoint does not use port 443: $BOOTSTRAP_SERVER" >&2
  exit 1
}

metadata=$(kcat -b "$BOOTSTRAP_SERVER" -F "$KCAT_CONFIG" -L -J)
broker_count=$(jq '.brokers | length' <<<"$metadata")

((broker_count > 0)) || {
  echo "FAIL: metadata contained no brokers" >&2
  exit 1
}

bad_ports=$(jq '[.brokers[] | select(.port != 443)] | length' <<<"$metadata")
((bad_ports == 0)) || {
  echo "FAIL: metadata advertised a non-443 broker" >&2
  jq '.brokers' <<<"$metadata" >&2
  exit 1
}

escaped_domain=${KAFKA_DOMAIN//./\\.}
broker_regex="^${BROKER_LABEL_PREFIX:-broker}-[0-9]+\\.${escaped_domain}$"
bad_names=$(jq --arg regex "$broker_regex" '[.brokers[] | select((.name | test($regex)) | not)] | length' <<<"$metadata")
((bad_names == 0)) || {
  echo "FAIL: metadata advertised an unexpected broker hostname; expected regex $broker_regex" >&2
  jq '.brokers' <<<"$metadata" >&2
  exit 1
}

native_names=$(jq '[.brokers[] | select(.name | endswith(".amazonaws.com"))] | length' <<<"$metadata")
((native_names == 0)) || {
  echo "FAIL: native AWS broker hostnames leaked through metadata" >&2
  jq '.brokers' <<<"$metadata" >&2
  exit 1
}

echo "PASS: $broker_count broker endpoint(s) use the expected external hostname pattern and port 443"
jq -r '.brokers[] | "  broker id=\(.id) endpoint=\(.name):\(.port)"' <<<"$metadata"
