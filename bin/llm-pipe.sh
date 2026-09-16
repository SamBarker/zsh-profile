#!/usr/bin/env zsh
# llm-pipe.sh — thin dispatch layer: reads stdin, sends to chosen LLM, writes to stdout.
#
# Usage (source or call directly):
#   llm_prompt [--llm BACKEND] [--model MODEL] PROMPT_TEXT
#
# BACKEND choices:
#   claude  — Anthropic Claude CLI  (claude -p "...")         [default]
#   bob     — IBM Bob CLI           (bob run "...")
#   omlx    — local oMLX server     (OpenAI-compatible REST)
#
# MODEL overrides the per-backend default:
#   claude  default: (claude CLI picks its own default)
#   bob     default: (bob picks its own default)
#   omlx    default: first model listed by the running server
#
# Environment variables (alternative to flags):
#   CONTRIBUTIONS_LLM        backend name
#   CONTRIBUTIONS_LLM_MODEL  model name / tag
#   OMLX_BASE_URL            base URL for omlx  (default: http://localhost:8000)

_llm_pipe_claude() {
    local prompt="$1" model="$2"
    if [[ -n "$model" ]]; then
        claude --model "$model" -p "$prompt"
    else
        claude -p "$prompt"
    fi
}

_llm_pipe_bob() {
    local prompt="$1" model="$2"
    local stdin_text
    stdin_text=$(cat)
    local full_prompt="${stdin_text}"$'\n\n'"${prompt}"
    if [[ -n "$model" ]]; then
        bob run --mode ask --disable-mcp --disable-subagents --max-turns 1 --model "$model" "$full_prompt"
    else
        bob run --mode ask --disable-mcp --disable-subagents --max-turns 1 "$full_prompt"
    fi
}

_llm_pipe_omlx() {
    local prompt="$1" model="$2"
    local base_url="${OMLX_BASE_URL:-http://localhost:8000}"
    local stdin_text
    stdin_text=$(cat)

    # Resolve API key: env var takes precedence, otherwise read from ~/.omlx/settings.json
    local api_key="${OMLX_API_KEY:-}"
    if [[ -z "$api_key" ]]; then
        api_key=$(jq -r '.auth.api_key // empty' ~/.omlx/settings.json 2>/dev/null) || true
    fi
    local auth_header=()
    [[ -n "$api_key" ]] && auth_header=(-H "Authorization: Bearer ${api_key}")

    # Resolve model: use explicit arg, env var, or query the server for the first available
    if [[ -z "$model" ]]; then
        model=$(curl -sf "${auth_header[@]}" "${base_url}/v1/models" \
            | jq -r '.data[0].id // empty' 2>/dev/null) || true
    fi
    if [[ -z "$model" ]]; then
        echo "omlx: could not determine a model — pass --model or start the server first" >&2
        return 1
    fi

    # Prepend /no_think to suppress Qwen3 chain-of-thought blocks in the output
    local payload
    payload=$(jq -n \
        --arg model "$model" \
        --arg system "/no_think ${prompt}" \
        --arg user "$stdin_text" \
        '{
            model: $model,
            messages: [
                {role: "system", content: $system},
                {role: "user",   content: $user}
            ],
            stream: false
        }')

    curl -sf "${auth_header[@]}" "${base_url}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        | jq -r '.choices[0].message.content'
}

llm_prompt() {
    local backend="${CONTRIBUTIONS_LLM:-claude}"
    local model="${CONTRIBUTIONS_LLM_MODEL:-}"
    local prompt=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --llm)   backend="$2"; shift 2 ;;
            --model) model="$2";   shift 2 ;;
            *)       prompt="$1";  shift   ;;
        esac
    done

    case "$backend" in
        claude) _llm_pipe_claude "$prompt" "$model" ;;
        bob)    _llm_pipe_bob    "$prompt" "$model" ;;
        omlx)   _llm_pipe_omlx   "$prompt" "$model" ;;
        *)
            echo "llm_prompt: unknown backend '${backend}' (choose: claude, bob, omlx)" >&2
            return 1
            ;;
    esac
}
