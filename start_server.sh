#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
elif [[ -f backend/.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source backend/.env
  set +a
elif [[ -f "$HOME/.miqdar_env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$HOME/.miqdar_env"
  set +a
fi

export GEMINI_MODEL="${GEMINI_MODEL:-gemini-3.1-flash-lite-preview}"
export GEMINI_FALLBACK_MODELS="${GEMINI_FALLBACK_MODELS:-gemini-3-flash-preview,gemini-flash-latest}"
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  export MIQDAR_RECOGNITION_PROVIDER="${MIQDAR_RECOGNITION_PROVIDER:-gemini}"
fi

if [[ ! -f database/miqdar_nutrition.db ]]; then
  python3 database/scripts/build_database.py
fi

export PYTHONPATH="$project_dir/backend${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m miqdar_backend.server \
  --db database/miqdar_nutrition.db \
  --host "${MIQDAR_HOST:-0.0.0.0}" \
  --port "${MIQDAR_PORT:-8080}"
