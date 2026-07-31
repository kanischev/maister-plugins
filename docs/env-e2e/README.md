# env-e2e package — reference

Ephemeral docker-compose environment + Playwright e2e as **readiness
evidence**. One `check` node owns the whole env lifecycle atomically; the
verdict routes the graph; artifacts land in the run dir on every attempt;
teardown is trap-guaranteed. Machine-only by design: zero published ports, no
preview surface — evidence instead of live carcasses.

Normative SSOT: [design spec](specs/2026-07-31-env-e2e-design.md). Package
quick-start: [`packages/env-e2e/README.md`](../../packages/env-e2e/README.md).

## The flow — `env-e2e`

```
implement (ai_coding) ── success ──> e2e (check) ── pass ──> done
   ^        ^                          │
   │        └───── fail (rework ≤3) ───┘
   └── rework (fresh budget) ── review (human) <── escalate (onExhaustion)
```

| Node | Type | What it does |
| --- | --- | --- |
| `implement` | `ai_coding` | Works the task; sees `{{ e2e_comments }}` (auto-loop feedback) and `{{ review_comments }}` (post-escalation human guidance), both runner-seeded empty on the first pass. Produces `impl-diff`. Standard infra `retry_policy` (2 attempts on SPAWN/EXECUTOR_UNAVAILABLE/CHECKPOINT/ACP_PROTOCOL). |
| `e2e` | `check` | Runs `scripts/run-e2e.sh` from the installed revision (`MAISTER_FLOW_DIR`, engine ≥ 3.3.0) with `settings.timeoutMs: 900000`. Emits the result JSON via `MAISTER_OUTPUT_FILE`; `decide.from: output.verdict` routes `pass → done`, `fail → implement` (bounded rework, `commentsVar: e2e_comments`), `escalate → review` on exhaustion. Produces `e2e-report` (kind `test_report`, `requiredFor: [review, merge]`) + `e2e-logs` (kind `log`) every attempt. |
| `review` | `human` | Escalation surface (reached only via `onExhaustion`). Blocking `artifact_required` gate on `e2e-report` — review cannot complete without the current red evidence. Single decision `rework` restarts the loop with a fresh budget (`resetTargets: [e2e]`); giving up is the run-level abandon action. **`pass` is the only path to `done`** — the flow never auto-ships a red suite. |

## Script phase machine (`flows/env-e2e/scripts/run-e2e.sh`)

`init → config → preflight → up → seed → test → capture → result`, teardown
via trap on EVERY exit path. Verbose `[env-e2e:<phase>]` logging;
`MAISTER_E2E_DEBUG=1` adds `set -x`.

| Failure class | Meaning | Exit | Run outcome |
| --- | --- | --- | --- |
| `config` | Bad invocation/config: missing `.maister-env-e2e.sh`, unset `E2E_COMPOSE_FILES`/`E2E_RUNNER_SERVICE`, listed compose file absent, runner service not in `--profile e2e config --services` | ≠ 0, before any resource exists | run **Failed** (`PRECONDITION`) — rework can't fix config |
| `env` | Infra: docker daemon unreachable, `up --wait` timeout, seed failure, capture failure | ≠ 0, best-effort evidence + guaranteed teardown | run **Failed** (`PRECONDITION`) |
| `test` | The runner service executed and exited non-zero (test failures AND Playwright internal errors both map to `fail` — safe worst case: an extra rework round reads the error) | 0 | verdict `fail` → rework loop |

## Result contract

`$MAISTER_OUTPUT_FILE` JSON (validated against `schemas/e2e-result.json`,
platform `formSchemaSchema` grammar — openness by construction):

| Field | Required | Content |
| --- | --- | --- |
| `verdict` | yes | `pass` ⇔ runner exit 0; enum ≡ the decide-producible transition keys |
| `summary` | yes | One line from the line-reporter counters (e.g. `2 passed (4.1s)`), falls back to the exit code |
| `e2e_comments` | yes | fail: last ~40 runner lines (spec names + first errors) — injected into the next `implement` attempt; pass: short all-green note |
| `stats` | no | optional counters (not emitted by v1) |

The failing block is ALSO printed last on stdout for the human step log; the
injection channel is always the JSON field.

## Evidence

- `e2e-report.tar.gz` — `playwright-report/` + `test-results/` (traces) +
  `test-output.log` (full runner output). A missing report dir becomes a
  `MISSING-REPORT.txt` marker inside the tar, never a skipped artifact.
- `e2e-compose-logs.txt` — `docker compose logs --no-color` of the whole
  stack, captured BEFORE teardown.
- Both re-produced on every attempt; `requiredFor: [review, merge]` currency
  on the report is the green-path promotion gate (evidence-readiness Check 1).

## Teardown & isolation

- Compose project `maister-run-<runId>` (`-p` everywhere) → concurrent runs
  are collision-free by construction; zero `ports:` anywhere.
- Trap (EXIT/TERM/INT, armed before the first compose call): best-effort
  capture → force-remove labeled containers (a killed CLI can orphan a
  `run --rm` one-off) → `down --volumes --remove-orphans --timeout 10`.
  Group-TERM tolerant (the trap spawns fresh processes); the engine's 30 s
  SIGKILL grace bounds it.
- Residual orphans exist only on SIGKILL-class deaths (grace exceeded,
  > 4 MiB combined step output, hard web-process crash):

```bash
docker compose ls | grep maister-run-
docker ps --filter "name=maister-run-"
docker compose -p maister-run-<id> down --volumes --remove-orphans
```

## Requirements (ADR-091 preflight)

Probed on the **web tier** in the project repo BEFORE any worktree/session/
token spend; each failure is actionable (`PRECONDITION` with hints):
`docker info` · `docker compose version` · `test -f .maister-env-e2e.sh`.

Host expectations: Docker daemon + compose v2 on the web tier (cli/check
nodes execute there); engine ≥ 3.3.0 (`MAISTER_FLOW_DIR`, ADR-154 — the `:?`
command guard fails actionably on older engines); registry egress for the
runner's `npm ci` ("fully internal" = zero published ports, not zero egress);
images pre-pulled (the bootstrap does this) so the first run fits the timeout
budget; `settings.timeoutMs` 900 s ≤ the `MAISTER_MAX_CLI_TIMEOUT_MS` host
ceiling (default 1 h).

## Per-project config — `.maister-env-e2e.sh`

Sourced bash at the consuming repo's root (versions WITH the tested branch):

```bash
E2E_COMPOSE_FILES=(compose.e2e.yml)  # required; repo-relative; -f merge order
E2E_RUNNER_SERVICE="e2e"             # required; profile "e2e" service running Playwright
E2E_WAIT_TIMEOUT=120                 # optional; seconds for `up --wait`
E2E_SEED_COMMAND='$E2E_COMPOSE exec -T db psql …'  # optional; host bash -c after up
E2E_ENV=(FIXTURE_RED=1)              # optional; NAME=VALUE → compose interpolation + runner env
```

`$E2E_COMPOSE` (the full `docker compose -p <proj> -f …` prefix) is exported
for seed commands. All docker invocations run under
`env -i PATH HOME COMPOSE_PROJECT_NAME + E2E_ENV` — web-tier values never
reach the containers (defense-in-depth over platform ADR-153); `DOCKER_HOST`
is not propagated (use a docker context).

## Fixture walkthrough

```bash
packages/env-e2e/examples/bootstrap-fixture.sh /path/to/fx-green
packages/env-e2e/examples/bootstrap-fixture.sh --red /path/to/fx-red
```

Each bootstrap: refuses a non-empty target, copies the fixture (nginx `web` +
postgres `db`, both healthchecked; Playwright runner under compose profile
`e2e`; committed lockfile pinning `@playwright/test` to the runner image
version), writes `maister.yaml` + `.maister-env-e2e.sh` (`--red` appends
`E2E_ENV=(FIXTURE_RED=1)`, turning `red.spec.ts` red), git-inits, pre-pulls
images, prints registration steps. Green ends done-side; red exercises
fail → rework → escalation. Green + red running simultaneously are the
concurrency proof (distinct `maister-run-*` projects).

## Testing the package itself

`packages/env-e2e/tests/test-run-e2e.sh` — self-contained 10-case bash
harness (docker required): config errors, up-wait timeout, pass/fail
contracts (incl. tar contents), group-SIGTERM teardown, bad-service
pre-validation, secret-sanitization via container env dump, failing-summary
extraction. Evidence dirs are kept under the printed work root.
