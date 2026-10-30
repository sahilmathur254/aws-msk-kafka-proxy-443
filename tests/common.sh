#!/usr/bin/env bash

set -euo pipefail

require_command() {
  command -v "$1" >/dev/null || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_env() {
  local name=$1
  [[ -n "${!name:-}" ]] || {
    echo "Required environment variable is not set: $name" >&2
    exit 1
  }
}

kafka_bin() {
  local executable=$1
  if [[ -n "${KAFKA_HOME:-}" && -x "${KAFKA_HOME}/bin/${executable}" ]]; then
    printf '%s\n' "${KAFKA_HOME}/bin/${executable}"
  elif command -v "$executable" >/dev/null; then
    command -v "$executable"
  else
    echo "Cannot find ${executable}; set KAFKA_HOME or add Kafka CLI tools to PATH" >&2
    exit 1
  fi
}

timeout_command() {
  if command -v timeout >/dev/null; then
    command -v timeout
  elif command -v gtimeout >/dev/null; then
    command -v gtimeout
  else
    echo "Install GNU coreutils (timeout/gtimeout)" >&2
    exit 1
  fi
}

new_topic_name() {
  if [[ -n "${TEST_TOPIC:-}" ]]; then
    printf '%s\n' "$TEST_TOPIC"
  else
    printf 'proxy-443-%s-%s\n' "$(date +%s)" "$$"
  fi
}

delete_topic_unless_kept() {
  local topic=$1
  local topics_cli=$2
  if [[ "${KEEP_TEST_TOPIC:-0}" != "1" ]]; then
    "$topics_cli" \
      --bootstrap-server "$BOOTSTRAP_SERVER" \
      --command-config "$CLIENT_CONFIG" \
      --delete \
      --if-exists \
      --topic "$topic" >/dev/null 2>&1 || true
  fi
}
