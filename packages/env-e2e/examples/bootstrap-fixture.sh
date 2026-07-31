#!/usr/bin/env bash
# Bootstrap an env-e2e fixture project into <target>: copy the fixture, git
# init + commit, write maister.yaml, pre-pull images, print registration
# steps. `--red` turns the toggleable spec red (rework-loop exerciser).
# Green + red instances double as the concurrency pair (AC-3).
set -euo pipefail

usage() {
  echo "Usage: $0 [--red] <target-dir>" >&2
  exit 2
}

RED=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --red) RED=1 ;;
    -*) usage ;;
    *) [[ -n "$TARGET" ]] && usage; TARGET="$arg" ;;
  esac
done
[[ -n "$TARGET" ]] || usage

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixture" && pwd)"

if [[ -e "$TARGET" ]] && [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
  echo "ERROR: target exists and is not empty: $TARGET" >&2
  exit 2
fi

echo "[bootstrap] copying fixture -> $TARGET"
mkdir -p "$TARGET"
cp -R "$FIXTURE_DIR/." "$TARGET/"

PROJECT_NAME="$(basename "$TARGET" | tr '[:upper:]' '[:lower:]' | tr '_.' '--')"

echo "[bootstrap] writing maister.yaml (project: $PROJECT_NAME)"
cat > "$TARGET/maister.yaml" <<EOF
schemaVersion: 2
project:
  name: $PROJECT_NAME
flows: []
EOF

if [[ "$RED" == "1" ]]; then
  echo "[bootstrap] enabling the RED toggle (FIXTURE_RED=1 via E2E_ENV)"
  printf '\n# Bootstrap --red: makes red.spec.ts fail — the rework-loop exerciser.\nE2E_ENV=(FIXTURE_RED=1)\n' >> "$TARGET/.maister-env-e2e.sh"
fi

echo "[bootstrap] git init + initial commit"
git -C "$TARGET" init -q -b main
git -C "$TARGET" add -A
git -C "$TARGET" -c user.name="env-e2e-bootstrap" -c user.email="bootstrap@env-e2e.local" commit -q -m "env-e2e fixture project"

echo "[bootstrap] pre-pulling images (keeps the first run inside the timeout budget)"
ensure_image() {
  if docker pull -q "$1"; then return 0; fi
  if docker image inspect "$1" >/dev/null 2>&1; then
    echo "[bootstrap] WARN: pull failed but $1 is present locally — continuing" >&2
    return 0
  fi
  echo "[bootstrap] ERROR: cannot pull $1 and it is not present locally" >&2
  return 1
}
ensure_image nginx:alpine
ensure_image postgres:16-alpine
ensure_image mcr.microsoft.com/playwright:v1.60.0-noble

cat <<EOF

[bootstrap] done: $TARGET $( [[ "$RED" == "1" ]] && echo '(RED variant)' )

Next steps (MAIster):
  1. Register the project: UI "Add project" with path $TARGET
     (or place it under MAISTER_PROJECTS_DIR and restart).
  2. Add the plugins repo as a package source (admin > packages) if absent,
     then attach package "env-e2e" to the project.
  3. Create a task on the project board (flow: env-e2e) and Launch.
     Green variant ends done-side; RED variant exercises the fail->rework
     loop and escalates after 3 attempts.

Manual sweep (crash-only orphans):
  docker compose ls | grep maister-run-
  docker compose -p maister-run-<id> down --volumes --remove-orphans
EOF
