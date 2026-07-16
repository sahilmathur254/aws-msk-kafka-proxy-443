#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_command aws
require_command kcat
require_env AWS_REGION
require_env ECS_CLUSTER
require_env ECS_SERVICE
require_env BOOTSTRAP_SERVER
require_env KCAT_CONFIG

if [[ "${CONFIRM_STOP_TASK:-}" != "yes" ]]; then
  cat >&2 <<'MESSAGE'
This test stops one running ECS task and ECS will replace it.
Verify AWS_REGION, ECS_CLUSTER, and ECS_SERVICE, then rerun with:
  export CONFIRM_STOP_TASK=yes
MESSAGE
  exit 2
fi

mapfile -t tasks < <(
  aws ecs list-tasks \
    --region "$AWS_REGION" \
    --cluster "$ECS_CLUSTER" \
    --service-name "$ECS_SERVICE" \
    --desired-status RUNNING \
    --query 'taskArns[]' \
    --output text | tr '\t' '\n'
)

((${#tasks[@]} >= 2)) || {
  echo "FAIL: expected at least two running tasks before failover test; found ${#tasks[@]}" >&2
  exit 1
}

target_task=${tasks[0]}
results=$(mktemp)
monitor_pid=""
cleanup() {
  [[ -n "$monitor_pid" ]] && kill "$monitor_pid" >/dev/null 2>&1 || true
  rm -f "$results"
}
trap cleanup EXIT

(
  for attempt in $(seq 1 60); do
    if kcat -b "$BOOTSTRAP_SERVER" -F "$KCAT_CONFIG" -L -J >/dev/null 2>&1; then
      echo "success $attempt" >> "$results"
    else
      echo "failure $attempt" >> "$results"
    fi
    sleep 1
  done
) &
monitor_pid=$!

sleep 5
echo "Stopping task: $target_task"
aws ecs stop-task \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --task "$target_task" \
  --reason "Intentional Kafka proxy failover test" >/dev/null

wait "$monitor_pid"
monitor_pid=""

successes=$(grep -c '^success ' "$results" || true)
failures=$(grep -c '^failure ' "$results" || true)

replacement_deadline=$((SECONDS + 300))
while ((SECONDS < replacement_deadline)); do
  running=$(
    aws ecs list-tasks \
      --region "$AWS_REGION" \
      --cluster "$ECS_CLUSTER" \
      --service-name "$ECS_SERVICE" \
      --desired-status RUNNING \
      --query 'length(taskArns)' \
      --output text
  )
  ((running >= 2)) && break
  sleep 10
done

if ((successes < 50 || failures > 10 || running < 2)); then
  echo "FAIL: successes=$successes failures=$failures running_tasks=$running" >&2
  exit 1
fi

echo "PASS: service remained available and returned to at least two running tasks"
echo "Metadata checks: successes=$successes failures=$failures"
