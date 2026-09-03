#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <project-slug>" >&2
  exit 64
fi

project_slug=$1
case "$project_slug" in
  ''|*[!A-Za-z0-9._-]*)
    echo "invalid project slug: $project_slug" >&2
    exit 65
    ;;
esac

if ! command -v uv >/dev/null 2>&1; then
  echo "BMAD TEA v1.24.0 requires uv with Python 3.11+" >&2
  exit 69
fi

project_root=$(pwd -P)
skill_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
scripts_dir="$project_root/_bmad/scripts"
config_file="$project_root/_bmad/config.toml"
tea_config="$project_root/_bmad/tea/config.yaml"

mkdir -p "$scripts_dir" "$project_root/_bmad/tea" "$project_root/docs/test-artifacts"
cp "$skill_root/scripts/config_utils.py" "$scripts_dir/config_utils.py"
cp "$skill_root/scripts/resolve_customization.py" "$scripts_dir/resolve_customization.py"

if [ ! -f "$config_file" ]; then
  printf '%s\n' \
    '[core]' \
    "project_name = \"$project_slug\"" \
    'user_name = "MAIster"' \
    'communication_language = "English"' \
    'document_output_language = "English"' \
    'output_folder = "docs"' \
    > "$config_file"
elif ! grep -Eq '^\[core\][[:space:]]*$' "$config_file"; then
  printf '\n' >> "$config_file"
  printf '%s\n' \
    '[core]' \
    "project_name = \"$project_slug\"" \
    'user_name = "MAIster"' \
    'communication_language = "English"' \
    'document_output_language = "English"' \
    'output_folder = "docs"' \
    >> "$config_file"
fi

if [ ! -f "$tea_config" ]; then
  printf '%s\n' \
    "project_name: \"$project_slug\"" \
    'user_name: "MAIster"' \
    'communication_language: "English"' \
    'document_output_language: "English"' \
    'output_folder: "docs"' \
    'test_artifacts: "docs/test-artifacts"' \
    'tea_use_playwright_utils: true' \
    'tea_use_pactjs_utils: true' \
    'tea_pact_mcp: "none"' \
    'tea_browser_automation: "auto"' \
    'tea_execution_mode: "auto"' \
    'tea_capability_probe: true' \
    'test_stack_type: "auto"' \
    'ci_platform: "auto"' \
    'test_framework: "auto"' \
    'risk_threshold: "p1"' \
    'test_design_output: "test-design"' \
    'test_review_output: "test-reviews"' \
    'trace_output: "traceability"' \
    > "$tea_config"
fi

echo "[tea substrate] BMAD TEA v1.24.0 runtime ready"
