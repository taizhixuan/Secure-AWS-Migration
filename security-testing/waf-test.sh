#!/usr/bin/env bash
# Probe AWS WAF with malicious-looking requests. WAF should return HTTP 403 for
# the attack payloads, while a legitimate request returns 200.
# (-k accepts the self-signed certificate used for the demo HTTPS listener.)
#
# Usage: ./waf-test.sh https://<alb-dns-name>
set -uo pipefail

BASE="${1:-}"
if [ -z "$BASE" ]; then
  echo "Usage: $0 https://<alb-dns-name>"
  exit 1
fi

req() { curl -sk -o /dev/null -w "%{http_code}" "$1"; }

echo "[*] Baseline (legitimate) request:"
printf "    GET /login.php                      -> %s   (expect 200)\n" "$(req "$BASE/login.php")"

echo "[*] SQL-injection attempts (expect 403 from WAF):"
printf "    /search.php?q=' OR '1'='1           -> %s\n" "$(req "$BASE/search.php?q=%27%20OR%20%271%27%3D%271")"
printf "    /search.php?q=UNION SELECT users    -> %s\n" "$(req "$BASE/search.php?q=1%20UNION%20SELECT%20username%2Cpassword%20FROM%20users")"
printf "    /search.php?q=1; DROP TABLE users   -> %s\n" "$(req "$BASE/search.php?q=1%3B%20DROP%20TABLE%20users")"

echo "[*] XSS / known-bad-input attempt (expect 403):"
printf "    /search.php?q=<script>alert(1)</script> -> %s\n" "$(req "$BASE/search.php?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")"

echo
echo "[i] 403 = blocked at the edge by AWS WAF before reaching the application."
echo "[i] The app is ALSO safe by itself (prepared statements) - defense-in-depth."
