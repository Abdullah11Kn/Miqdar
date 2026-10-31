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
exec python3 app.py "$@"
