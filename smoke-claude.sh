#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=${0:A:h}
PROXY_HOST=${PROXY_HOST:-127.0.0.1}
PORT=${PORT:-$(python3 - <<'PY'
import socket
sock = socket.socket()
sock.bind(('127.0.0.1', 0))
print(sock.getsockname()[1])
sock.close()
PY
)}
LOG_FILE=${LOG_FILE:-/tmp/claude-openai-litellm.log}
PROMPT=${1:-Reply with only the answer to 2+2.}

: "${OPENAI_API_KEY:?OPENAI_API_KEY must be set}"

if [[ -z ${LITELLM_MASTER_KEY:-} ]]; then
  export LITELLM_MASTER_KEY="litellm-$(openssl rand -hex 24)"
fi

proxy_pid=
cleanup() {
  if [[ -n ${proxy_pid:-} ]]; then
    kill "$proxy_pid" >/dev/null 2>&1 || true
    wait "$proxy_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

PROXY_HOST="$PROXY_HOST" PORT="$PORT" "$ROOT_DIR/start-proxy.sh" >"$LOG_FILE" 2>&1 &
proxy_pid=$!

for _ in {1..60}; do
  if curl -sS -o /dev/null "http://$PROXY_HOST:$PORT" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! nc -z "$PROXY_HOST" "$PORT" >/dev/null 2>&1; then
  echo "Proxy failed to start. See $LOG_FILE" >&2
  exit 1
fi

echo "Using LiteLLM proxy at http://$PROXY_HOST:$PORT"
echo "== Raw LiteLLM Anthropic endpoint =="
request_json=$(jq -n --arg prompt "$PROMPT" '{model:"gpt-5.4",max_tokens:16,messages:[{role:"user",content:$prompt}]}')
curl -fsS "http://$PROXY_HOST:$PORT/v1/messages" \
  -H "content-type: application/json" \
  -H "x-api-key: $LITELLM_MASTER_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "$request_json" \
  | jq -r '.content[0].text'

echo
echo "== Claude Code headless via LiteLLM =="
export ANTHROPIC_BASE_URL="http://$PROXY_HOST:$PORT"
export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"
unset ANTHROPIC_AUTH_TOKEN
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1

claude -p \
  --model gpt-5.4 \
  --permission-mode bypassPermissions \
  --no-session-persistence \
  "$PROMPT"
