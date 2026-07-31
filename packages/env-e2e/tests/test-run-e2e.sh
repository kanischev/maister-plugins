#!/usr/bin/env bash
# env-e2e script test harness (spec §8): 10 one-behavior cases against
# flows/env-e2e/scripts/run-e2e.sh. Self-contained bash; requires docker +
# docker compose v2. Each case gets a fresh fixture copy (project dir) and a
# fresh temp run dir; MAISTER_FLOW_DIR points at the package's flow dir —
# exactly what a real install materializes. Evidence is kept under the
# printed work root. Exit 0 iff all cases pass.
set -uo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLOW_DIR="$PKG_DIR/flows/env-e2e"
SCRIPT="$FLOW_DIR/scripts/run-e2e.sh"
FIXTURE_DIR="$PKG_DIR/examples/fixture"
WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/env-e2e-harness-XXXXXX")"

PASS=0
FAIL=0
FAILED_CASES=""

log() { printf '%s\n' "$*"; }

harness_cleanup() {
  # Best-effort: no harness container/network may outlive the run.
  local ids
  ids="$(docker ps -aq --filter "name=maister-run-harness-" 2>/dev/null)"
  [[ -n "$ids" ]] && docker rm -f $ids >/dev/null 2>&1
  ids="$(docker network ls -q --filter "name=maister-run-harness-" 2>/dev/null)"
  [[ -n "$ids" ]] && docker network rm $ids >/dev/null 2>&1
  ids="$(docker volume ls -q --filter "name=maister-run-harness-" 2>/dev/null)"
  [[ -n "$ids" ]] && docker volume rm $ids >/dev/null 2>&1
  return 0
}
trap harness_cleanup EXIT

new_case() { # $1=case-id → sets PROJ_DIR RUN_DIR OUT_FILE PROJ_NAME LOG_FILE
  CASE_ID="$1"
  PROJ_DIR="$WORK_ROOT/$CASE_ID/project"
  RUN_DIR="$WORK_ROOT/$CASE_ID/run"
  mkdir -p "$PROJ_DIR" "$RUN_DIR"
  OUT_FILE="$RUN_DIR/output-e2e-1.json"
  LOG_FILE="$RUN_DIR/harness-output.log"
  PROJ_NAME="maister-run-harness-$CASE_ID-$$"
}

copy_fixture() { cp -R "$FIXTURE_DIR/." "$PROJ_DIR/"; }

run_script() { # foreground run; sets SCRIPT_EXIT
  (
    cd "$PROJ_DIR" &&
      MAISTER_OUTPUT_FILE="$OUT_FILE" MAISTER_FLOW_DIR="$FLOW_DIR" \
        bash "$SCRIPT" "$PROJ_NAME"
  ) >"$LOG_FILE" 2>&1
  SCRIPT_EXIT=$?
}

containers_gone() {
  [[ -z "$(docker ps -aq --filter "name=$PROJ_NAME" 2>/dev/null)" ]]
}

json_field() { # $1=field name → first string value, jq-free
  sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$OUT_FILE" 2>/dev/null | head -1
}

expect() { # $1=description, $2...=command; appends to CASE_ERRORS on failure
  if ! "${@:2}"; then
    CASE_ERRORS="$CASE_ERRORS
  - expected: $1"
    return 1
  fi
  return 0
}

# --- cases -----------------------------------------------------------------

case1_config_missing() {
  new_case c1
  run_script
  expect "exit != 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -ne 0
  expect "[env-e2e:config] marker in output" grep -q '\[env-e2e:config\]' "$LOG_FILE"
}

case2_var_missing() {
  new_case c2
  copy_fixture
  printf 'E2E_COMPOSE_FILES=(compose.e2e.yml)\n' > "$PROJ_DIR/.maister-env-e2e.sh"
  run_script
  expect "exit != 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -ne 0
  expect "config error names E2E_RUNNER_SERVICE" grep -q '\[env-e2e:config\].*E2E_RUNNER_SERVICE' "$LOG_FILE"
}

case3_compose_file_absent() {
  new_case c3
  copy_fixture
  printf 'E2E_COMPOSE_FILES=(compose.missing.yml)\nE2E_RUNNER_SERVICE="e2e"\n' > "$PROJ_DIR/.maister-env-e2e.sh"
  run_script
  expect "exit != 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -ne 0
  expect "config error names compose.missing.yml" grep -q '\[env-e2e:config\].*compose\.missing\.yml' "$LOG_FILE"
}

case4_up_wait_timeout() {
  new_case c4
  copy_fixture
  cat > "$PROJ_DIR/compose.broken.yml" <<'EOF'
services:
  web:
    healthcheck:
      test: ["CMD", "false"]
      interval: 1s
      timeout: 1s
      retries: 2
EOF
  cat > "$PROJ_DIR/.maister-env-e2e.sh" <<'EOF'
E2E_COMPOSE_FILES=(compose.e2e.yml compose.broken.yml)
E2E_RUNNER_SERVICE="e2e"
E2E_WAIT_TIMEOUT=10
EOF
  run_script
  expect "exit != 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -ne 0
  expect "teardown ran — no containers left" containers_gone
}

case5_pass_path() {
  new_case c5
  copy_fixture
  run_script
  expect "exit 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -eq 0
  expect "verdict is pass (got '$(json_field verdict)')" test "$(json_field verdict)" = "pass"
  expect "summary non-empty" test -n "$(json_field summary)"
  expect "e2e_comments key present" grep -q '"e2e_comments"' "$OUT_FILE"
  expect "report artifact exists" test -f "$RUN_DIR/e2e-report.tar.gz"
  expect "compose-logs artifact exists" test -f "$RUN_DIR/e2e-compose-logs.txt"
  expect "report tar contains playwright-report/" bash -c "tar -tzf '$RUN_DIR/e2e-report.tar.gz' | grep -q 'playwright-report/'"
  expect "report tar contains test-output.log" bash -c "tar -tzf '$RUN_DIR/e2e-report.tar.gz' | grep -q 'test-output.log'"
  expect "no stub marker in output" bash -c "! grep -q '\[env-e2e:stub\]' '$LOG_FILE'"
  expect "teardown ran — no containers left" containers_gone
}

case6_fail_path() {
  new_case c6
  copy_fixture
  printf '\nE2E_ENV=(FIXTURE_RED=1)\n' >> "$PROJ_DIR/.maister-env-e2e.sh"
  run_script
  expect "exit 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -eq 0
  expect "verdict is fail (got '$(json_field verdict)')" test "$(json_field verdict)" = "fail"
  expect "e2e_comments non-empty" grep -q '"e2e_comments"[[:space:]]*:[[:space:]]*"[^"]' "$OUT_FILE"
  expect "report artifact exists" test -f "$RUN_DIR/e2e-report.tar.gz"
  expect "compose-logs artifact exists" test -f "$RUN_DIR/e2e-compose-logs.txt"
  expect "teardown ran — no containers left" containers_gone
}

case7_sigterm_mid_test() {
  new_case c7
  copy_fixture
  local pidfile="$RUN_DIR/script.pid"

  (
    cd "$PROJ_DIR" &&
      MAISTER_OUTPUT_FILE="$OUT_FILE" MAISTER_FLOW_DIR="$FLOW_DIR" PIDFILE="$pidfile" \
        perl -e 'setpgrp(0,0); open(my $f, ">", $ENV{PIDFILE}) or die; print $f $$; close $f; exec "bash", @ARGV or die' "$SCRIPT" "$PROJ_NAME"
  ) >"$LOG_FILE" 2>&1 &
  local waiter=$!

  # Wait for the test phase (compose work active), then TERM the whole group.
  local deadline=$((SECONDS + 300))
  until grep -q '\[env-e2e:test\]' "$LOG_FILE" 2>/dev/null; do
    if ((SECONDS >= deadline)); then
      CASE_ERRORS="$CASE_ERRORS
  - expected: [env-e2e:test] phase reached within 300s (never appeared)"
      kill -TERM "-$(cat "$pidfile" 2>/dev/null || echo 999999)" 2>/dev/null
      wait "$waiter" 2>/dev/null
      return 1
    fi
    sleep 2
  done
  sleep 3
  kill -TERM "-$(cat "$pidfile")" 2>/dev/null

  local exit_deadline=$((SECONDS + 90))
  while kill -0 "$(cat "$pidfile")" 2>/dev/null; do
    if ((SECONDS >= exit_deadline)); then
      CASE_ERRORS="$CASE_ERRORS
  - expected: script group exited within 90s of TERM"
      return 1
    fi
    sleep 2
  done
  wait "$waiter" 2>/dev/null
  # Teardown runs from the trap AFTER the TERM — give it a bounded window.
  local gone_deadline=$((SECONDS + 60))
  until containers_gone; do
    if ((SECONDS >= gone_deadline)); then
      CASE_ERRORS="$CASE_ERRORS
  - expected: teardown after group-TERM — containers still present"
      return 1
    fi
    sleep 2
  done
  return 0
}

case8_bad_runner_service() {
  new_case c8
  copy_fixture
  printf 'E2E_COMPOSE_FILES=(compose.e2e.yml)\nE2E_RUNNER_SERVICE="doesnotexist"\n' > "$PROJ_DIR/.maister-env-e2e.sh"
  run_script
  expect "exit != 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -ne 0
  expect "config error names the missing service" grep -q '\[env-e2e:config\].*doesnotexist' "$LOG_FILE"
  expect "nothing left behind" containers_gone
}

case9_sanitization() {
  new_case c9
  copy_fixture
  cat > "$PROJ_DIR/compose.envdump.yml" <<'EOF'
services:
  e2e:
    command: sh -c "env | sort > /work/env-dump.txt"
EOF
  cat > "$PROJ_DIR/.maister-env-e2e.sh" <<'EOF'
E2E_COMPOSE_FILES=(compose.e2e.yml compose.envdump.yml)
E2E_RUNNER_SERVICE="e2e"
EOF
  (
    cd "$PROJ_DIR" &&
      SECRET_PROBE="leak-me-xyz" MAISTER_OUTPUT_FILE="$OUT_FILE" MAISTER_FLOW_DIR="$FLOW_DIR" \
        bash "$SCRIPT" "$PROJ_NAME"
  ) >"$LOG_FILE" 2>&1
  SCRIPT_EXIT=$?
  expect "exit 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -eq 0
  expect "container env dump was produced" test -f "$PROJ_DIR/env-dump.txt"
  expect "SECRET_PROBE not visible inside the container" bash -c "! grep -q 'SECRET_PROBE' '$PROJ_DIR/env-dump.txt'"
}

case10_summary_extraction() {
  new_case c10
  copy_fixture
  printf '\nE2E_ENV=(FIXTURE_RED=1)\n' >> "$PROJ_DIR/.maister-env-e2e.sh"
  run_script
  expect "exit 0 (got $SCRIPT_EXIT)" test "$SCRIPT_EXIT" -eq 0
  expect "failing block names red.spec.ts" grep -q 'red\.spec\.ts' "$OUT_FILE"
  expect "failing block carries an error line" grep -qiE 'error|expect' "$OUT_FILE"
}

# --- driver ----------------------------------------------------------------

run_case() { # $1=id  $2=fn
  CASE_ERRORS=""
  log ""
  log "=== $1 ($2)"
  if "$2" && [[ -z "$CASE_ERRORS" ]]; then
    log "PASS $1"
    PASS=$((PASS + 1))
  else
    log "FAIL $1${CASE_ERRORS}"
    log "     evidence: $WORK_ROOT/$CASE_ID"
    FAIL=$((FAIL + 1))
    FAILED_CASES="$FAILED_CASES $1"
  fi
}

log "env-e2e harness — script: $SCRIPT"
log "work root (evidence kept): $WORK_ROOT"
command -v docker >/dev/null || { log "FATAL: docker required"; exit 2; }
docker compose version >/dev/null 2>&1 || { log "FATAL: docker compose v2 required"; exit 2; }

run_case "case 1/10 config-missing" case1_config_missing
run_case "case 2/10 var-missing" case2_var_missing
run_case "case 3/10 compose-file-absent" case3_compose_file_absent
run_case "case 4/10 up-wait-timeout" case4_up_wait_timeout
run_case "case 5/10 pass-path" case5_pass_path
run_case "case 6/10 fail-path" case6_fail_path
run_case "case 7/10 sigterm-mid-test" case7_sigterm_mid_test
run_case "case 8/10 bad-runner-service" case8_bad_runner_service
run_case "case 9/10 sanitization" case9_sanitization
run_case "case 10/10 summary-extraction" case10_summary_extraction

log ""
log "RESULT: PASS=$PASS FAIL=$FAIL${FAILED_CASES:+ — failed:$FAILED_CASES}"
[[ "$FAIL" -eq 0 ]]
