#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR=${0:A:h}
PROXY_HOST=${PROXY_HOST:-127.0.0.1}
PORT=${PORT:-4000}

: "${OPENAI_API_KEY:?OPENAI_API_KEY must be set}"
: "${LITELLM_MASTER_KEY:?LITELLM_MASTER_KEY must be set}"

exec uvx --from 'litellm[proxy]' litellm \
  --config "$ROOT_DIR/config.yaml" \
  --host "$PROXY_HOST" \
  --port "$PORT"
