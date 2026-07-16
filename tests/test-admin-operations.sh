#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_env BOOTSTRAP_SERVER
require_env CLIENT_CONFIG
[[ -r "$CLIENT_CONFIG" ]] || { echo "CLIENT_CONFIG is not readable: $CLIENT_CONFIG" >&2; exit 1; }

topics=$(kafka_bin kafka-topics.sh)
configs=$(kafka_bin kafka-configs.sh)
topic=$(new_topic_name)
trap 'delete_topic_unless_kept "$topic" "$topics"' EXIT

"$topics" \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --command-config "$CLIENT_CONFIG" \
  --create \
  --topic "$topic" \
  --partitions 3 \
  --replication-factor "${REPLICATION_FACTOR:-1}"

description=$(
  "$topics" \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CLIENT_CONFIG" \
    --describe \
    --topic "$topic"
)

[[ "$description" == *"$topic"* ]] || {
  echo "FAIL: topic description did not contain $topic" >&2
  exit 1
}

"$configs" \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --command-config "$CLIENT_CONFIG" \
  --entity-type topics \
  --entity-name "$topic" \
  --describe >/dev/null

echo "PASS: create, describe, configuration query, and cleanup admin operations succeeded for $topic"
