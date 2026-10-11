#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

if [[ -f backend/.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source backend/.env
  set +a
fi

if [[ ! -f database/miqdar_nutrition.db ]]; then
  python3 database/scripts/build_database.py
fi

export PYTHONPATH="$project_dir/backend${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m miqdar_backend.server \
  --db database/miqdar_nutrition.db \
  --host "${MIQDAR_HOST:-0.0.0.0}" \
  --port "${MIQDAR_PORT:-8080}"
