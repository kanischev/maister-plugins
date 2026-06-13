#!/usr/bin/env bash
set -euo pipefail

# Install the pinned OpenSpec CLI if it is not already on PATH. MAIster may run
# this at package-install time (exec-trust-gated). The `os-init` flow's `ensure`
# node performs the same install per-run, and os-dev/os-propose/os-apply declare
# a `requirements` probe (ADR-091) that refuses launch if the CLI is still
# absent — so this script is the convenience installer, not the only path.
command -v openspec >/dev/null 2>&1 || npm i -g @fission-ai/openspec@1.4.1
echo "[openspec setup] openspec CLI: $(command -v openspec 2>/dev/null || echo MISSING)" >&2
