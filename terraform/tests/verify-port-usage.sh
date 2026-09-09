#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$project_root/tests/common.sh"

require_env BOOTSTRAP_SERVER
require_env CLIENT_CONFIG
require_command tcpdump

host=${BOOTSTRAP_SERVER%:*}
[[ "${BOOTSTRAP_SERVER##*:}" == "443" ]] || {
  echo "FAIL: bootstrap endpoint is not port 443" >&2
  exit 1
}

if command -v dig >/dev/null; then
  mapfile -t proxy_ips < <(dig +short A "$host" | sort -u)
elif command -v getent >/dev/null; then
  mapfile -t proxy_ips < <(getent ahostsv4 "$host" | awk '{print $1}' | sort -u)
else
  echo "Install dig or getent to resolve the proxy endpoint" >&2
  exit 1
fi

((${#proxy_ips[@]} > 0)) || { echo "No IPv4 addresses resolved for $host" >&2; exit 1; }

pcap=$(mktemp "${TMPDIR:-/tmp}/proxy-443.XXXXXX.pcap")
capture_pid=""
cleanup() {
  if [[ -n "$capture_pid" ]]; then
    sudo kill "$capture_pid" >/dev/null 2>&1 || true
    wait "$capture_pid" 2>/dev/null || true
  fi
  rm -f "$pcap"
}
trap cleanup EXIT

filter="tcp and ("
separator=""
for ip in "${proxy_ips[@]}"; do
  filter+="${separator}dst host ${ip}"
  separator=" or "
done
filter+=")"

echo "Capturing outbound TCP traffic to ${proxy_ips[*]} while running a Kafka workload..."
sudo tcpdump -i any -nn -U -w "$pcap" "$filter" >/dev/null 2>&1 &
capture_pid=$!
sleep 2

"$project_root/tests/test-produce-consume.sh"
sleep 2
sudo kill "$capture_pid" >/dev/null 2>&1 || true
wait "$capture_pid" 2>/dev/null || true
capture_pid=""

mapfile -t observed_ports < <(
  sudo tcpdump -nn -r "$pcap" 2>/dev/null |
    awk '{for (i=1; i<=NF; i++) if ($i == ">") print $(i+1)}' |
    sed 's/:$//' |
    awk -F. '{print $NF}' |
    sort -nu
)

((${#observed_ports[@]} > 0)) || {
  echo "FAIL: capture contained no outbound proxy TCP traffic" >&2
  exit 1
}

for port in "${observed_ports[@]}"; do
  [[ "$port" == "443" ]] || {
    echo "FAIL: observed a connection to a resolved proxy address on TCP $port" >&2
    exit 1
  }
done

echo "PASS: all observed TCP connections to the resolved proxy addresses used port 443"
echo "Run verify-metadata.sh as the complementary proof that no native MSK address was advertised."
