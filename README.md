# Claude Code → OpenAI via LiteLLM

Minimal local setup for running Claude Code headless against OpenAI `gpt-5.4` through LiteLLM's Anthropic-compatible `/v1/messages` endpoint.

## What this repo includes

- `config.yaml` — LiteLLM config with a `gpt-5.4` alias.
- `start-proxy.sh` — starts LiteLLM locally on `127.0.0.1:4000` by default.
- `smoke-claude.sh` — starts a disposable local proxy, checks the raw Anthropic endpoint, then runs Claude Code headless.
- `examples/anthropic_reasoning.py` — example proxy hook for mapping Claude Code effort to OpenAI Responses reasoning.

## Quick start

```bash
export OPENAI_API_KEY="..."
export LITELLM_MASTER_KEY="litellm-dev-key"

./smoke-claude.sh
```

Optional prompt override:

```bash
./smoke-claude.sh 'Reply with only the answer to 3+5.'
```

If you want to keep the proxy running separately:

```bash
export OPENAI_API_KEY="..."
export LITELLM_MASTER_KEY="litellm-dev-key"

./start-proxy.sh
```

## Manual Claude call

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:4000"
export ANTHROPIC_API_KEY="$LITELLM_MASTER_KEY"
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1

claude -p \
  --model gpt-5.4 \
  --permission-mode bypassPermissions \
  --no-session-persistence \
  'Reply with only the answer to 2+2.'
```

## Production note

This repo is intentionally just the minimal local smoke test.

My production setup uses a separate LiteLLM proxy repo and deployment with extra callbacks for auth, auditing, and model allowlisting. That private infrastructure is **not** included here.

The one production-specific behavior worth calling out is reasoning effort:

- Claude Code sends Anthropic-style `/v1/messages` requests.
- OpenAI `gpt-5.4` expects reasoning effort on the Responses API.
- Depending on your LiteLLM version/path, Anthropic `output_config.effort` may not automatically become OpenAI `reasoning.effort`.

If you hit that, use the example hook in `examples/anthropic_reasoning.py:1` and register it as a LiteLLM callback.
