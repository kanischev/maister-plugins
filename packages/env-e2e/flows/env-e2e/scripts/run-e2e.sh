#!/usr/bin/env bash
# env-e2e lifecycle script — T3 CONTRACT STUB.
# Satisfies the node contract shape (result JSON + both artifact files) so the
# graph is statically valid and installable; the real compose+Playwright
# lifecycle (spec §6) lands in T5/T6. Every T-RED harness case must FAIL
# against this stub — that is the recorded RED baseline.
set -euo pipefail

echo "[env-e2e:stub] contract stub — the compose+playwright lifecycle is not implemented yet"

RUN_DIR="$(dirname "${MAISTER_OUTPUT_FILE:?MAISTER_OUTPUT_FILE missing — the e2e node must declare output.result}")"

tar -czf "$RUN_DIR/e2e-report.tar.gz" -T /dev/null
: > "$RUN_DIR/e2e-compose-logs.txt"

printf '%s\n' '{"verdict":"pass","summary":"stub — no tests executed","e2e_comments":"stub run; real lifecycle lands in T5/T6"}' > "$MAISTER_OUTPUT_FILE"
