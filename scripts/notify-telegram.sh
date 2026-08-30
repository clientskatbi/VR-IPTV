#!/usr/bin/env bash
# Telegram notification helper for CI.
# Usage:
#   ./scripts/notify-telegram.sh "Title" "Body" [silent]
#
# Reads token from $TELEGRAM_BOT_TOKEN env var or ~/.telegram_token.txt.
# Reads owner ID from $TELEGRAM_OWNER_ID (default: 7304090625).

set -e

TITLE="${1:-CI Update}"
BODY="${2:-No details}"
SILENT="${3:-}"

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
if [[ -z "$TOKEN" && -f "$HOME/.telegram_token.txt" ]]; then
  TOKEN="$(cat $HOME/.telegram_token.txt)"
fi
if [[ -z "$TOKEN" && -f "$HOME/.config/telegram_token.txt" ]]; then
  TOKEN="$(cat $HOME/.config/telegram_token.txt)"
fi

OWNER_ID="${TELEGRAM_OWNER_ID:-7304090625}"

if [[ -z "$TOKEN" ]]; then
  echo "❌ No TELEGRAM_BOT_TOKEN found" >&2
  exit 1
fi

# Escape body for JSON (replace " with \" and newlines with \n)
BODY_ESCAPED=$(printf '%s' "$BODY" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])')

PAYLOAD=$(printf '{"chat_id":%s,"text":"%s\n\n%s","parse_mode":"HTML","disable_notification":%s}' \
  "$OWNER_ID" \
  "$TITLE" \
  "$BODY_ESCAPED" \
  "$( [[ -n "$SILENT" ]] && echo "true" || echo "false" )")

curl -s --connect-timeout 5 --max-time 25 \
  "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" > /dev/null

echo "✅ Telegram notification sent"