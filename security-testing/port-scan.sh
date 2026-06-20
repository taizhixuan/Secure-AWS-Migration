#!/usr/bin/env bash
# Port-scan the public ALB endpoint from an external machine.
# Expected result: only 80/tcp and 443/tcp are reachable; everything else
# (e.g. 22 SSH, 3306 MySQL) is filtered because of the Security Groups + NACLs.
#
# Usage: ./port-scan.sh <alb-dns-name>
set -uo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <alb-dns-name>"
  exit 1
fi

echo "[*] Scanning top 1000 TCP ports on $TARGET ..."
nmap -Pn -T4 --top-ports 1000 "$TARGET"

echo
echo "[*] Explicit check of sensitive ports (22 SSH, 80 HTTP, 443 HTTPS, 3306 MySQL):"
nmap -Pn -p 22,80,443,3306 "$TARGET"

echo
echo "[i] Expected: 80/tcp open, 443/tcp open; 22/tcp and 3306/tcp filtered."
echo "[i] The database is never internet-facing (private, isolated subnets)."
