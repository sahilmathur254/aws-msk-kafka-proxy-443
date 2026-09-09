#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_env BOOTSTRAP_SERVER
require_env CLIENT_CONFIG
[[ -r "$CLIENT_CONFIG" ]] || { echo "CLIENT_CONFIG is not readable: $CLIENT_CONFIG" >&2; exit 1; }

topics=$(kafka_bin kafka-topics.sh)
producer=$(kafka_bin kafka-console-producer.sh)
consumer=$(kafka_bin kafka-console-consumer.sh)
timeout_bin=$(timeout_command)

topic=$(new_topic_name)
record="proxy-443-smoke-$(date +%s)-$$-$RANDOM"
trap 'delete_topic_unless_kept "$topic" "$topics"' EXIT

"$topics" \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --command-config "$CLIENT_CONFIG" \
  --create \
  --if-not-exists \
  --topic "$topic" \
  --partitions 3 \
  --replication-factor "${REPLICATION_FACTOR:-1}" >/dev/null

printf '%s\n' "$record" | "$producer" \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --producer.config "$CLIENT_CONFIG" \
  --topic "$topic"

consumed=$(
  "$timeout_bin" 45 "$consumer" \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --consumer.config "$CLIENT_CONFIG" \
    --topic "$topic" \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 30000
)

[[ "$consumed" == *"$record"* ]] || {
  echo "FAIL: produced record was not consumed" >&2
  printf 'Expected: %s\nReceived: %s\n' "$record" "$consumed" >&2
  exit 1
}

echo "PASS: produced and consumed a record through $BOOTSTRAP_SERVER on topic $topic"
