#!/usr/bin/env bash
# Minimal, dependency-free check of an Anthropic API key + request shape.
#
# "No final response was produced" from a wrapper is NOT an auth rejection.
# This makes one bare /v1/messages call so you see the REAL HTTP outcome.
# It never prints your key.
#
# Usage:
#   export ANTHROPIC_API_KEY="sk-ant-..."
#   ./tools/diagnose-anthropic.sh [model]
set -euo pipefail

MODEL="${1:-claude-opus-4-8}"
: "${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY first (export ANTHROPIC_API_KEY=sk-ant-...)}"

if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  echo "WARNING: both ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN are set."
  echo "The SDK sends both headers and the API rejects that with 401. Unset one."
  echo
fi

echo "POST https://api.anthropic.com/v1/messages   (model=$MODEL)"
resp="$(curl -sS -w $'\n%{http_code}' https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "{\"model\":\"$MODEL\",\"max_tokens\":64,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: bootstrap ok\"}]}")"

code="$(printf '%s' "$resp" | tail -n1)"
body="$(printf '%s' "$resp" | sed '$d')"

echo "HTTP $code"
echo "$body"
echo
case "$code" in
  200) echo "-> KEY VALID. If hermes still fails, the bug is in how it builds the request or"
       echo "   reads the response (model id, removed params, text-first content parsing)."
       echo "   stop_reason=refusal => classifier declined this prompt (key still fine)."
       echo "   200 with empty content => model stopped on tool_use / empty thinking blocks." ;;
  401) echo "-> AUTH. Key invalid/revoked, or ANTHROPIC_API_KEY + ANTHROPIC_AUTH_TOKEN both set."
       echo "   ONLY case where rotating the key helps." ;;
  403) echo "-> PERMISSION/BILLING. Key can't use '$MODEL', or a workspace/billing restriction." ;;
  404) echo "-> BAD MODEL ID. '$MODEL' is a typo or a retired model. Use e.g. claude-opus-4-8." ;;
  400) echo "-> BAD REQUEST. Payload invalid for this model: on current models, temperature/"
       echo "   top_p/top_k and thinking.budget_tokens are REJECTED and assistant prefills 400."
       echo "   Rotating the key will NOT fix it -- fix the request body." ;;
  429) echo "-> RATE LIMITED. Back off / honor retry-after." ;;
  *)   echo "-> Server/other error (5xx/529 are retryable)." ;;
esac

[ "$code" = "200" ] || exit 1
