#!/usr/bin/env bash
set -euo pipefail

IPS=("127.10.0.1/32" "127.10.0.2/32" "127.10.0.3/32" "127.10.0.4/32" "127.10.0.5/32" "127.10.0.6/32" "127.10.0.7/32")

if [[ "${1:-}" == "down" || "${1:-}" == "--uninstall" ]]; then
  for ip in "${IPS[@]}"; do
    base="${ip%/32}"
    echo "Removing $base from lo0 (if present)…"
    sudo ifconfig lo0 -alias "$base" 2>/dev/null || true
  done
  exit 0
fi

for ip in "${IPS[@]}"; do
  base="${ip%/32}"
  if ifconfig lo0 | grep -q "inet $base "; then
    echo "lo0 already has $base"
  else
    echo "Adding $ip to lo0…"
    sudo ifconfig lo0 alias "$ip"
  fi
done

echo
echo "Current lo0 aliases:"
ifconfig lo0 | grep "inet 127.10."

