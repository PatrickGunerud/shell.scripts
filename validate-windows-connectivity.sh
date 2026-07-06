#!/usr/bin/env bash
set -euo pipefail

# validate-windows-connectivity.sh
#
# Purpose:
#   Validate from macOS that Windows clients on this network can pass
#   Microsoft's NCSI (Network Connectivity Status Indicator) checks:
#     1. DNS probe    — dns.msftncsi.com must resolve to 131.107.255.255
#     2. HTTP probe   — connecttest.txt body must be "Microsoft Connect Test"
#     3. HTTP headers — probe must return status 200
#     4. HTTPS probe  — optional reachability check
#     5. IPv6 DNS     — optional ipv6.msftconnecttest.com resolution
#   A DNS answer that is filtered/rewritten (e.g. by AdGuard Home) is the
#   most common cause of Windows showing "No Internet" despite working
#   connectivity.
#
# Usage:
#   validate-windows-connectivity.sh [dns_server]
#
# Example:
#   validate-windows-connectivity.sh 172.20.10.27
#
#   If no DNS server is provided, the Mac's default resolvers are used.
#
# Exit codes:
#   0  all checks passed (warnings allowed)
#   1  one or more checks failed
#
# Requirements:
#   nslookup, curl, scutil, awk, sed, paste (all present on stock macOS)

EXPECTED_DNS_IP="131.107.255.255"
EXPECTED_HTTP_BODY="Microsoft Connect Test"
DNS_TEST_HOST="dns.msftncsi.com"
HTTP_TEST_URL="http://www.msftconnecttest.com/connecttest.txt"
HTTPS_TEST_URL="https://www.msftconnecttest.com/connecttest.txt"
IPV6_TEST_HOST="ipv6.msftconnecttest.com"

DNS_SERVER="${1:-}"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "[FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo "[WARN] $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

trim() {
  awk '{$1=$1; print}'
}

get_default_dns_servers() {
  # scutil may be unavailable/fail in odd environments; under pipefail its
  # non-zero status would propagate through the pipe and, via set -e, kill
  # the script — so tolerate failure and let the caller warn on empty.
  scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3}' | sort -u || true
}

resolve_with_nslookup() {
  local host="$1"
  local server="${2:-}"

  # nslookup exits non-zero on NXDOMAIN/timeout — an expected outcome this
  # script exists to detect, not a script error. Tolerate it (|| true) so
  # set -e doesn't abort; callers judge the captured output instead.
  if [[ -n "$server" ]]; then
    nslookup "$host" "$server" 2>/dev/null || true
  else
    nslookup "$host" 2>/dev/null || true
  fi
}

extract_addresses() {
  awk '
    BEGIN { found=0 }
    /^Address: / { print $2 }
    /^Addresses: / { found=1; sub(/^Addresses: /, "", $0); print $0; next }
    found && /^[[:space:]]+/ { gsub(/^[[:space:]]+/, "", $0); print $0 }
  ' | sed '/^#/d' | sed '/^$/d'
}

section "Windows Connectivity Validation"

if [[ -n "$DNS_SERVER" ]]; then
  echo "Using explicit DNS server: $DNS_SERVER"
else
  echo "Using system default DNS resolvers"
  DEFAULT_DNS="$(get_default_dns_servers | paste -sd ', ' -)"
  if [[ -n "$DEFAULT_DNS" ]]; then
    echo "Detected macOS resolvers: $DEFAULT_DNS"
  else
    warn "Could not determine default DNS resolvers from macOS"
  fi
fi

section "1. DNS test: ${DNS_TEST_HOST}"

DNS_OUTPUT="$(resolve_with_nslookup "$DNS_TEST_HOST" "$DNS_SERVER")"
echo "$DNS_OUTPUT"
echo

DNS_IPS="$(printf '%s\n' "$DNS_OUTPUT" | extract_addresses | tail -n +2 | trim)"

if [[ -z "$DNS_IPS" ]]; then
  fail "No DNS answer returned for ${DNS_TEST_HOST}"
else
  echo "Resolved IP(s):"
  printf '%s\n' "$DNS_IPS"
  echo

  if printf '%s\n' "$DNS_IPS" | grep -Fxq "$EXPECTED_DNS_IP"; then
    pass "${DNS_TEST_HOST} returned expected IP ${EXPECTED_DNS_IP}"
  else
    fail "${DNS_TEST_HOST} did not return expected IP ${EXPECTED_DNS_IP}"
  fi
fi

section "2. HTTP probe: ${HTTP_TEST_URL}"

HTTP_BODY="$(curl -4 -fsS --max-time 10 "$HTTP_TEST_URL" 2>/dev/null || true)"

if [[ -z "$HTTP_BODY" ]]; then
  fail "Could not fetch ${HTTP_TEST_URL}"
else
  echo "Response body:"
  echo "$HTTP_BODY"
  echo

  if [[ "$HTTP_BODY" == "$EXPECTED_HTTP_BODY" ]]; then
    pass "HTTP probe returned expected body"
  else
    fail "HTTP probe body did not match expected value"
  fi
fi

section "3. HTTP headers"

HTTP_HEADERS="$(curl -4 -sS -D - -o /dev/null --max-time 10 "$HTTP_TEST_URL" 2>/dev/null || true)"

if [[ -z "$HTTP_HEADERS" ]]; then
  warn "Could not retrieve HTTP headers"
else
  echo "$HTTP_HEADERS"
  if printf '%s\n' "$HTTP_HEADERS" | grep -Eq '^HTTP/[0-9.]+ 200'; then
    pass "HTTP probe returned status 200"
  else
    fail "HTTP probe did not return status 200"
  fi
fi

section "4. HTTPS probe (optional but useful)"

HTTPS_STATUS="$(curl -4 -sS -o /dev/null -w '%{http_code}' --max-time 10 "$HTTPS_TEST_URL" 2>/dev/null || true)"

if [[ -z "$HTTPS_STATUS" || "$HTTPS_STATUS" == "000" ]]; then
  warn "HTTPS probe failed or was unreachable"
else
  echo "HTTPS status: $HTTPS_STATUS"
  if [[ "$HTTPS_STATUS" == "200" ]]; then
    pass "HTTPS probe reachable"
  else
    warn "HTTPS probe returned non-200 status: $HTTPS_STATUS"
  fi
fi

section "5. IPv6 DNS probe (optional)"

IPV6_OUTPUT="$(resolve_with_nslookup "$IPV6_TEST_HOST" "$DNS_SERVER")"
echo "$IPV6_OUTPUT"
echo

if printf '%s\n' "$IPV6_OUTPUT" | grep -qE 'NXDOMAIN|server can.t find|Non-existent domain'; then
  warn "IPv6 connectivity test host did not resolve"
else
  IPV6_IPS="$(printf '%s\n' "$IPV6_OUTPUT" | extract_addresses | tail -n +2 | trim)"
  if [[ -n "$IPV6_IPS" ]]; then
    pass "IPv6 test host resolved"
  else
    warn "No IPv6 answer returned for ${IPV6_TEST_HOST}"
  fi
fi

section "6. Summary"

echo "Passed : $PASS_COUNT"
echo "Failed : $FAIL_COUNT"
echo "Warnings: $WARN_COUNT"

echo
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "Overall result: Windows connectivity checks look healthy."
  exit 0
else
  echo "Overall result: One or more Windows connectivity checks failed."
  echo "If DNS passed but HTTP failed, Windows may still report 'No Internet'."
  echo "If dns.msftncsi.com did not return ${EXPECTED_DNS_IP}, that is a strong indicator of filtering or rewriting."
  exit 1
fi