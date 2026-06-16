#!/usr/bin/env bash
set -euo pipefail

# Install the pinned Spec Kit `specify` CLI if it is not already on PATH. MAIster
# may run this at package-install time (exec-trust-gated). The `sk-init` flow's
# `ensure` node performs the same install per-run, and `sk-dev` declares a
# `requirements` probe (ADR-091) that refuses launch if the CLI / scaffold is
# still absent — so this script is the convenience installer, not the only path.
#
# `specify` is a Python tool; install via uv (preferred) or pipx. Pinned to the
# Spec Kit git tag v0.10.3.
command -v specify >/dev/null 2>&1 || {
  if command -v uv >/dev/null 2>&1; then
    uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v0.10.3
  elif command -v pipx >/dev/null 2>&1; then
    pipx install "git+https://github.com/github/spec-kit.git@v0.10.3"
  else
    echo "[spec-kit setup] need uv or pipx to install the specify CLI" >&2
    exit 1
  fi
}
echo "[spec-kit setup] specify CLI: $(command -v specify 2>/dev/null || echo MISSING)" >&2
