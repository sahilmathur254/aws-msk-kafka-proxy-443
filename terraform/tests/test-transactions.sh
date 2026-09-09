#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_env BOOTSTRAP_SERVER
require_env KCAT_CONFIG
require_command python3

python3 -c 'import confluent_kafka' >/dev/null 2>&1 || {
  echo "Install the pinned dependency first:" >&2
  echo "  python3 -m pip install -r clients/requirements.txt" >&2
  exit 1
}

python3 "$project_root/clients/transactions.py"
