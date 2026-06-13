#!/usr/bin/env bash
set -euo pipefail

# Inert no-op. MAIster delivers the superpowers skills bundle via capability
# materialization (the whole capability/skills/ tree is copied into the
# session worktree's .claude/skills/ at launch — see the package README). There
# is nothing to install at setup time; superpowers is a zero-dependency,
# zero-setup skills library.
echo "[superpowers setup] no-op: skills delivered via MAIster capability materialization" >&2
exit 0
