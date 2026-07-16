#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_env BOOTSTRAP_SERVER
require_env CLIENT_CONFIG

topics=$(kafka_bin kafka-topics.sh)
producer=$(kafka_bin kafka-console-producer.sh)
consumer=$(kafka_bin kafka-console-consumer.sh)
groups=$(kafka_bin kafka-consumer-groups.sh)
timeout_bin=$(timeout_command)

topic=$(new_topic_name)
group="proxy-443-group-$(date +%s)-$$"
trap 'delete_topic_unless_kept "$topic" "$topics"' EXIT

"$topics" \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --command-config "$CLIENT_CONFIG" \
  --create \
  --topic "$topic" \
  --partitions 3 \
  --replication-factor "${REPLICATION_FACTOR:-1}" >/dev/null

printf 'one\ntwo\nthree\n' | "$producer" \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --producer.config "$CLIENT_CONFIG" \
  --topic "$topic"

"$timeout_bin" 45 "$consumer" \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --consumer.config "$CLIENT_CONFIG" \
  --topic "$topic" \
  --group "$group" \
  --from-beginning \
  --max-messages 3 \
  --timeout-ms 30000 >/dev/null

group_description=$(
  "$groups" \
    --bootstrap-server "$BOOTSTRAP_SERVER" \
    --command-config "$CLIENT_CONFIG" \
    --describe \
    --group "$group"
)

[[ "$group_description" == *"$group"* ]] || {
  echo "FAIL: consumer group could not be described" >&2
  printf '%s\n' "$group_description" >&2
  exit 1
}

echo "PASS: consumer group coordination and offset commit succeeded for $group"
