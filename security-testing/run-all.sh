#!/usr/bin/env bash
# Run ALL Part E security tests (Linux/macOS). Usage: ./run-all.sh [alb-dns] [region] [prefix]
# Needs: AWS CLI configured (T3/T4); nmap (T1); curl (T2/T5).
set -uo pipefail
ALB="${1:-mmu-sis-prod-alb-1870207398.ap-southeast-1.elb.amazonaws.com}"
REGION="${2:-ap-southeast-1}"
PREFIX="${3:-mmu-sis-prod}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "========== T1 - PORT SCAN =========="
"$HERE/port-scan.sh" "$ALB"
echo; echo "========== T2 - WAF (SQLi / XSS) =========="
"$HERE/waf-test.sh" "https://$ALB"
echo; echo "========== T3 + T4 - ENCRYPTION + CLOUDTRAIL =========="
AWS_REGION="$REGION" "$HERE/verify-encryption.sh" "$PREFIX"
echo; echo "========== T5 - HTTPS / redirect =========="
curl -sk -o /dev/null -w "HTTP  -> %{http_code} (expect 301)\n" "http://$ALB/"
curl -sk -o /dev/null -w "HTTPS -> %{http_code} (expect 200)\n" "https://$ALB/health.php"
echo; echo "========== ALL SECURITY TESTS DONE =========="
