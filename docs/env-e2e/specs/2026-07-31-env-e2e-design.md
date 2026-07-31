# env-e2e package design spec (2026-07-31)

Normative design for `packages/env-e2e`: an ephemeral, fully internal
docker-compose environment + Playwright e2e run packaged as ONE `check` node
whose script owns the whole env lifecycle atomically, converting the result
into readiness evidence. Written spec-first (SDD); implementation MUST be
consistent with this document. Where this spec corrects the original request
text, the correction is marked **[grounding]** with the platform-code citation.

Companion platform contract: MAIster
[ADR-154](https://github.com/albertkanischev/maister) (`MAISTER_FLOW_DIR` for
cli/check node actions, engine `3.3.0`) + `docs/flow-dsl.md` §"env whitelist +
secret blocklist" + `docs/system-analytics/flow-graph.md` §Expectations.

Status: normative, consistency-gated (TS3, §11); implementation target
`packages/env-e2e`, release tag `env-e2e/v1.0.0`.

---

## 1. Scope and non-goals

**v0 = evidence, not preview.** The env is machine-only: zero published host
ports, reachable only inside its compose network, ALWAYS torn down; debugging
happens from captured report/traces/logs. Explicitly out of scope (deferred
design exists in owner notes, 2026-07-28): any user-facing preview surface
(proxy/Traefik/forwardAuth, wildcard DNS, published ports), env parking on
NeedsInput/Idle, env spanning multiple nodes, split env-up/env-down nodes,
`environment:` sections in `maister.yaml`, platform GC/sweeper integration,
k8s or non-compose providers, external CI ingestion (`external_check`).

## 2. Functional requirements (normative)

| ID | Requirement |
| --- | --- |
| FR-1 | ONE `check` node (`e2e`) owns the env lifecycle **atomically**: config → preflight → up → seed → test → capture → down, in a single script invocation; teardown is guaranteed by a shell trap on EVERY exit path (success, failure, error, TERM/INT, incl. group-TERM). |
| FR-2 | **Zero published ports**: neither the fixture nor the contract permits `ports:` on any service; the runner reaches services by compose-network internal DNS only. |
| FR-3 | **Per-run isolation** by compose project name `maister-run-<runId>` (`-p` on every compose invocation); concurrent runs are collision-free by construction. |
| FR-4 | **Evidence captured on BOTH verdicts**: `e2e-report.tar.gz` (Playwright `playwright-report/` + `test-results/` + full runner output log) and `e2e-compose-logs.txt` (`docker compose logs --no-color`), both written into the run dir (`dirname "$MAISTER_OUTPUT_FILE"`), both on every exit-0 attempt (per-attempt currency). |
| FR-5 | **Exit-0 protocol**: the script exits 0 whenever the runner service executed (tests ran) — the verdict travels in the result JSON and routes via `decide`; non-zero exit is reserved for `config`/`env` failure classes (run fails hard — rework cannot fix an env). **[grounding]** check nodes have NO failure transition: non-zero exit ⇒ node Failed `PRECONDITION` ⇒ run Failed (`web/lib/flows/runner-cli.ts`, `runner-graph.ts`); `retry_policy` on `check` is silently stripped (`config.schema.ts`). |
| FR-6 | **Rework feedback**: the failing summary is a string field named exactly `e2e_comments` in the result JSON. **[grounding]** rework comment injection reads `result.vars[commentsVar]`; cli/check vars are folded from the `MAISTER_OUTPUT_FILE` JSON — stdout is NOT injected automatically (`runner-graph.ts` commentsVar seam, `node-output.ts` fold). |
| FR-7 | **Config contract** `.maister-env-e2e.sh` (§5) with validation: every violation produces an actionable `[env-e2e:config] …` line and exit 1 BEFORE any compose resource exists. |
| FR-8 | **Preflight requirements** (ADR-091): `docker info`, `docker compose version`, `test -f .maister-env-e2e.sh` — launch is refused (`PRECONDITION`, with hints) before any worktree/session/token spend. |
| FR-9 | **Teardown guaranteed** on all script exit paths: trap on EXIT/TERM/INT armed BEFORE the first compose call runs best-effort capture then `docker compose -p <proj> down --volumes --remove-orphans --timeout 10`. Group-TERM tolerance: the trap spawns FRESH `docker compose` processes (they are not in the signal batch of a process-group TERM). Residual risk: SIGKILL (30 s engine grace exceeded, 4 MiB output cap, hard web-process crash) strands the env → documented sweep (FR-13). |
| FR-10 | **Sanitized child env**: every docker invocation runs under `env -i PATH="$PATH" HOME="$HOME" COMPOSE_PROJECT_NAME="<proj>" <E2E_ENV pairs>` — defense-in-depth over platform ADR-153; web-tier values beyond that set MUST NOT reach compose interpolation or containers. |
| FR-11 | **Packaged-script materialization**: `flows/env-e2e/scripts/run-e2e.sh` is the SSOT file (shipped INSIDE the flow dir — `MAISTER_FLOW_DIR` is the installed FLOW revision dir, which materializes the flow subdir plus package-root `schemas/`, NOT other package-root dirs; verified against the platform installer, `web/lib/flows.ts` copy + `materializePackageRootSchemas`). Executed via `bash "${MAISTER_FLOW_DIR:?env-e2e requires MAIster engine >= 3.3.0 (MAISTER_FLOW_DIR missing)}/scripts/run-e2e.sh" "maister-run-{{ run.id }}"`; `compat.engine_min: 3.3.0`. The install dir is read-only: the script writes ONLY to the worktree cwd and the run dir. |
| FR-12 | **Timeout budget**: the `e2e` node declares `settings.timeoutMs: 900000` (≤ the 1 h `MAISTER_MAX_CLI_TIMEOUT_MS` host ceiling); the fixture completes in < 300 s so the package also works on deployments predating the timeoutMs fix (default 300 s). |
| FR-13 | **Orphan sweep documented** (crash-only cases): `docker compose ls --filter name=maister-run-` / `docker ps --filter "name=maister-run-"`; stray teardown `docker compose -p maister-run-<id> down --volumes --remove-orphans`. |
| FR-14 | **Fixture + bootstrap**: `examples/fixture/` (web nginx + db postgres + playwright runner under profile `e2e`, green + toggleable red spec) and `examples/bootstrap-fixture.sh [--red] <target>`; green + red instances double as the concurrency pair. |

Non-functional:

| ID | Requirement |
| --- | --- |
| NFR-1 | Script structure follows SOLID/KISS/DRY: one function per phase, no duplicated compose argv assembly, behavior-preserving refactor guarded by the test harness. |
| NFR-2 | Verbose phase logging: every phase emits `[env-e2e:<phase>] …` lines; `MAISTER_E2E_DEBUG=1` enables `set -x`; failures print the failing command and a remedy. |
| NFR-3 | No secret values in artifacts, logs, stdout, or telemetry: the sanitized env (FR-10) bounds what containers can even see; the script never echoes the parent environment. |

## 3. Flow graph (normative)

Three nodes; `pass` is the ONLY path to the `done` terminal (greenness is
enforced by routing — never auto-ship a red suite).

```
implement (ai_coding) ── success ──> e2e (check)
   ^        ^                          │ decide.from: output.verdict
   │        └── rework (auto, ≤3) ──── fail
   │                                   │ pass ──> done
   └── rework (human, resets e2e) ─── escalate (onExhaustion)
                                       │
                                    review (human)
```

- `implement` — `ai_coding`; prompt references `{{ task.prompt }}`,
  `{{ e2e_comments }}` (auto-loop feedback) and `{{ review_comments }}`
  (post-escalation human feedback); both are commentsVars, runner-seeded empty
  on first visit. Produces `impl-diff` (kind `diff`). Standard infra
  `retry_policy` (attempts 2, on SPAWN/EXECUTOR_UNAVAILABLE/CHECKPOINT/
  ACP_PROTOCOL, `rewind-to-node-checkpoint`) per repo convention.
- `e2e` — `check`; `settings.timeoutMs: 900000`; command per FR-11;
  `output.result: { schema: ./schemas/e2e-result.json, required: true }`
  (arming `MAISTER_OUTPUT_FILE`); produces `e2e-report` (kind `test_report`,
  `path: e2e-report.tar.gz`, `requiredFor: [review, merge]`) + `e2e-logs`
  (kind `log`, `path: e2e-compose-logs.txt`); `decide: { from: output.verdict }`;
  `transitions: { pass: done, fail: implement, escalate: review }`;
  `rework: { allowedTargets: [implement], workspacePolicies: [keep], maxLoops: 3,
  commentsVar: e2e_comments, onExhaustion: escalate }`.
- `review` — `human` (escalation surface, reached ONLY via `onExhaustion`);
  `pre_finish` blocking `artifact_required` gate on `[e2e-report]`;
  `finish.human: { role: maintainer, decisions: [rework], commentsVar:
  review_comments }`; `transitions: { rework: implement }`;
  `rework: { allowedTargets: [implement], workspacePolicies: [keep], maxLoops: 3,
  commentsVar: review_comments, resetTargets: [e2e] }`. Giving up is a RUN-level
  action (abandon), not a flow decision — there is deliberately no decision
  that reaches `done`.

**Pinned `onExhaustion` syntax** (verified against platform
`web/lib/config.schema.ts` `reworkSchema` — `onExhaustion: z.string().min(1)`,
a free transition key validated ∈ the node's `transitions`; `resetTargets`
valid on a human node whose rework chain reaches the loop node):

```yaml
rework:
  allowedTargets: [implement]
  workspacePolicies: [keep]
  maxLoops: 3
  commentsVar: e2e_comments
  onExhaustion: escalate   # routes via transitions.escalate -> review
```

**Graph invariants:**

1. One e2e execution per attempt — the `artifact_required` gate and the
   readiness check only READ artifact currency; nothing re-executes the suite.
   **[grounding]** `gates-exec.ts` artifact_required checks
   `getCurrentArtifact` only.
2. `pass` is the only transition reaching `done`; `fail` and `escalate` both
   keep the run away from promotion until a green attempt exists.
3. Verdict enum ≡ decide-producible outcomes: `pass|fail` (schema enum) ⊆
   transition keys `{pass, fail, escalate}`; `escalate` is NOT producible by
   the verdict — it is reserved for `onExhaustion` routing. **[grounding]** a
   decide outcome not in transition keys is a runtime `CONFIG` refusal
   (`runner-graph.ts` allow-list guard).
4. **[grounding — corrects the request]** The blocking `artifact_required`
   gate on `e2e-report` lives on the `review` node's `pre_finish`, NOT on the
   `e2e` node itself: produces-recording runs AFTER a node's own pre_finish
   gates (`runner-graph.ts` M12 recording comment), so a same-node gate would
   ALWAYS fail its first attempt. Green-path promotion gating is carried by
   `requiredFor: [review, merge]` currency instead (evidence-readiness
   Check 1: a def with `requiredFor` blocks the phase unless a `current` row
   exists). The canonical human-review placement matches `docs/flow-dsl.md`
   ("review-refusal mechanism") and the `aif-dev` exemplar.
5. Rework staleness: re-entering `implement` stales downstream (`e2e`)
   artifacts; each e2e attempt re-produces both files → `supersedePrior`
   retires prior rows; currency always reflects the latest attempt.
6. `output.result.on_mismatch` is deliberately ABSENT: malformed result JSON
   means a broken script (not a flaky agent) — the default hard `CONFIG` fail
   is correct and loud.

## 4. Result JSON contract

Written by the script to `$MAISTER_OUTPUT_FILE` on every exit-0 path, last
step before exit (after captures, so a capture crash cannot produce a
verdict-without-evidence attempt).

```json
{
  "verdict": "pass" | "fail",       // REQUIRED; == docker compose run exit code 0 / non-0
  "summary": "…",                   // REQUIRED; one line, e.g. "2 passed, 1 failed (14.3s)"
  "e2e_comments": "…",              // REQUIRED; fail: failing block (spec names + first error
                                    //   lines, bounded tail ~40 lines); pass: short all-green note
  "stats": { "total": 3, "passed": 2, "failed": 1 }   // OPTIONAL, numbers
}
```

- **Schema grammar [grounding — corrects the request]:** the platform
  validates `output.result` against its OWN restricted grammar
  (`formSchemaSchema`: `{ schemaVersion, fields: [{name, type:
  string|number|boolean|enum|array|object, required?, options?, fields?}] }`) —
  NOT standard JSON Schema; there is no ajv and no `additionalProperties`
  keyword. Openness is by construction (only declared fields are checked), so
  the request's "additionalProperties: true" intent holds automatically.
  `schemas/e2e-result.json` therefore declares: `verdict` enum
  `[pass, fail]` required; `summary` string required; `e2e_comments` string
  required; `stats` object optional with number children.
- Verdict semantics: `pass` ⇔ the runner service exited 0. ANY non-zero runner
  exit (test failures AND Playwright internal errors) maps to `fail` — safe
  worst case: an extra rework round reads the error output.
- On exit≠0 paths (config/env class) the JSON MAY be absent — the engine never
  reads it for a failed action; stdout/stderr carry the actionable message.
- The failing block is ALSO printed last on stdout (human-readable step log),
  but stdout is never the injection channel (FR-6).

## 5. Per-project config contract — `.maister-env-e2e.sh`

Sourced bash at the consuming repo's root (no yq/jq host dependency; sourcing
adds no new trust — the run already executes project code). Versions WITH the
tested branch (deliberate: the config describes THAT revision's stack).

| Variable | Type | Required | Meaning |
| --- | --- | --- | --- |
| `E2E_COMPOSE_FILES` | bash array | yes, non-empty | Repo-relative compose files, `-f` merge order = array order. Every listed file must exist. |
| `E2E_RUNNER_SERVICE` | string | yes | Compose service (under profile `e2e`) that runs Playwright; must appear in `docker compose … --profile e2e config --services`. |
| `E2E_WAIT_TIMEOUT` | int seconds | no (default 120) | `up --wait --wait-timeout` budget. |
| `E2E_SEED_COMMAND` | string | no | Host `bash -c` command after up, before tests. Runs with the sanitized env + `E2E_COMPOSE` (see below). Non-zero exit = `env` class. |
| `E2E_ENV` | bash array of `NAME=VALUE` | no | Extra env: included in the sanitized env for compose `${}` interpolation AND passed as `-e NAME=VALUE` to `docker compose run` (reaches the test process). |

Exported helper for seed commands: `E2E_COMPOSE` — the full
`docker compose -p <proj> -f <file>…` prefix, so a seed command can run e.g.
`$E2E_COMPOSE exec -T db psql …` without knowing the run id.

**Validation rules (failure class `config`, exit 1, `[env-e2e:config] …`):**
missing file → "not found at <cwd>; create it (see package README)";
unset/empty `E2E_COMPOSE_FILES` or `E2E_RUNNER_SERVICE` → named-var message;
listed compose file absent → per-file message; runner service not in
`--profile e2e config --services` output → message listing available services.
Script-invocation guards in the same class: `$1` (compose project name)
missing/not matching `^[A-Za-z0-9][A-Za-z0-9_-]*$`; `MAISTER_OUTPUT_FILE`
unset.

## 6. Script phase machine — `scripts/run-e2e.sh`

`set -euo pipefail`. Phases, in order; every phase logs
`[env-e2e:<phase>] …` (NFR-2). `RUN_DIR="$(dirname "$MAISTER_OUTPUT_FILE")"`.

| # | Phase | Does | Failure class on error |
| --- | --- | --- | --- |
| 1 | `init` | Parse `$1` (project name), resolve `RUN_DIR`, **arm the trap** (EXIT/TERM/INT) BEFORE any compose call. | `config` |
| 2 | `config` | Source + validate `.maister-env-e2e.sh` (§5), incl. runner-service presence via `compose config --services` (daemon-less). | `config` |
| 3 | `preflight` | `docker info`, `docker compose version` (sanitized env). | `env` |
| 4 | `up` | `docker compose -p <proj> -f … up -d --wait --wait-timeout "${E2E_WAIT_TIMEOUT:-120}"`. | `env` |
| 5 | `seed` | `bash -c "$E2E_SEED_COMMAND"` when set (sanitized env + `E2E_COMPOSE`). | `env` |
| 6 | `test` | `docker compose -p <proj> -f … --profile e2e run --rm [-e E2E_ENV…] "$E2E_RUNNER_SERVICE"` under `set +e`; exit code captured; output tee'd to `$RUN_DIR/test-output.log` and stdout. | never fails the script (exit code = verdict) |
| 7 | `capture` | ALWAYS both files: tar worktree `playwright-report/` + `test-results/` + `test-output.log` → `$RUN_DIR/e2e-report.tar.gz` (missing dirs → `MISSING-REPORT.txt` marker inside the tar, never a skipped artifact); `docker compose … logs --no-color > $RUN_DIR/e2e-compose-logs.txt`. | `env` (capture must succeed on exit-0 paths — the produces backstop needs both files) |
| 8 | `result` | Build JSON (§4) from the runner exit code + `test-output.log` tail; write to `$MAISTER_OUTPUT_FILE`; print the failing block last on stdout. | `env` |
| 9 | `down` | Via the trap: best-effort capture (if not yet done) then `down --volumes --remove-orphans --timeout 10`; then exit 0 (verdict paths) / original non-zero (config/env). | — |

**Failure classes:** `config` — wrong invocation/config, nothing was created,
rework can't fix it → exit 1. `env` — docker/infra failed (preflight, up
timeout, seed, capture), evidence best-effort, teardown guaranteed → exit 1.
`test` — the runner ran and returned non-zero → verdict `fail`, exit 0.

**Teardown guarantees (FR-9):** trap covers normal exit, `set -e` errors,
TERM/INT; group-TERM (engine timeout) hits bash + children, and the trap's
fresh `docker compose down` processes are outside that signal batch; the
engine's 30 s SIGKILL grace bounds the trap — `down --timeout 10` fits.
SIGKILL paths (grace exceeded, > 4 MiB combined stdout+stderr, web-process
crash) strand the env by design → FR-13 sweep. **Bounded stdout:** the full
runner output goes into the report tar; stdout carries phase lines, the live
runner stream (fixture-sized; projects MUST use a line reporter), and the
bounded failing tail — staying far below the 4 MiB engine cap.

## 7. Fixture + bootstrap (`examples/`)

`examples/fixture/` — a minimal consuming project:

- `compose.e2e.yml`: `web` (nginx:alpine, wget-based healthcheck), `db`
  (postgres:16-alpine, `pg_isready` healthcheck, default `postgres/postgres`,
  db `app`), `e2e` (official Playwright image, `profiles: ["e2e"]`,
  `depends_on` web+db healthy, mounts the repo at `/work`, workdir `/work`,
  command `sh -c "npm ci --no-audit && npx playwright test --reporter=line"`).
  ZERO `ports:` anywhere (FR-2).
- `package.json` + committed `package-lock.json` (`@playwright/test` pinned).
- `playwright.config.ts`: `baseURL: http://web`, HTML reporter into
  `playwright-report/`, traces on-first-retry or on.
- `tests/home.spec.ts` (green: loads `/`, expects nginx welcome) +
  `tests/red.spec.ts` (toggleable: `expect(process.env.FIXTURE_RED ?? '').not.toBe('1')`).
- `.maister-env-e2e.sh`: files=(compose.e2e.yml), runner=e2e, seed exercising
  the db (`$E2E_COMPOSE exec -T db psql … CREATE TABLE/INSERT`).

`examples/bootstrap-fixture.sh [--red] <target>`: refuses a non-empty target
dir; copies the fixture; `git init` + initial commit; writes `maister.yaml` v2
(project name derived from the target dir name — green/red instances get
distinct names) + `.maister-env-e2e.sh` (appends `E2E_ENV=(FIXTURE_RED=1)` on
`--red`); PRE-PULLS the three images (keeps the live node inside FR-12's
budget); prints the registration/install/launch steps. `--red` reaches the
test process via `E2E_ENV` → `docker compose run -e FIXTURE_RED=1`.

## 8. Edge-case inventory (drives the T-RED harness)

The harness stubs `MAISTER_FLOW_DIR` to the package checkout's
`packages/env-e2e/flows/env-e2e` dir (the flow dir — what a real install
materializes) and `MAISTER_OUTPUT_FILE` to a file in a temp run dir.

Harness cases (one behavior each; ALL must be RED against the T3 stub):

| # | Case | Asserts |
| --- | --- | --- |
| 1 | Config file missing | exit≠0, `[env-e2e:config]` line |
| 2 | Required var missing (`E2E_RUNNER_SERVICE` unset) | exit≠0, named-var `[env-e2e:config]` line |
| 3 | Listed compose file absent | exit≠0, per-file `[env-e2e:config]` line |
| 4 | `up --wait` timeout (broken healthcheck override, small `E2E_WAIT_TIMEOUT`) | exit≠0, teardown ran (no `maister-run-*` containers) |
| 5 | Pass path | exit 0, JSON verdict=pass + required fields, BOTH artifact files exist in run dir, `e2e-report.tar.gz` contains real `playwright-report/` + `test-output.log` entries, NO `[env-e2e:stub]` marker on stdout, containers gone (stub-unfakeable — the T3 stub writes contract-shaped files but cannot fake tar contents or hide its marker) |
| 6 | Fail path (`FIXTURE_RED=1`) | exit 0, verdict=fail, `e2e_comments` non-empty, both artifacts exist, containers gone |
| 7 | SIGTERM mid-test (process-group TERM, emulating engine timeout) | teardown ran, no containers |
| 8 | Bad runner service name | exit≠0 (config class via `config --services` pre-validation), teardown ran / nothing left |
| 9 | Sanitization: `SECRET_PROBE=xyz` in parent env | env dump inside a container does NOT contain `SECRET_PROBE` (fixture-copy runner command dumps env to the mounted worktree) |
| 10 | Summary extraction quality | failing block contains the failing spec name + first error line |

Documented (non-harness) edges: engine timeout-abort at system level and
SIGKILL-after-grace (T11b); 4 MiB stdout cap policy (§6); seed failure = `env`
class; docker daemon dying mid-run = `env` class via compose errors; absent
`MAISTER_OUTPUT_FILE`/`$1` guards (§5); Playwright internal error ⇒ verdict
`fail` (§4); missing report dirs ⇒ `MISSING-REPORT.txt` marker (§6 phase 7);
`npm ci` needs registry egress ("fully internal" = zero published ports, not
zero egress — README states this).

## 9. Acceptance criteria → verifier map

| AC | Statement (measurable) | Verifier |
| --- | --- | --- |
| AC-1 | Green fixture: launch → env healthy, `docker ps` shows no published ports on `maister-run-*` → verdict `pass` routes to `done`-side → both artifact rows `current` → readiness green (evidence Check 1 satisfied, no blocking-gate obstruction) → `docker compose ls` clean after | T8 |
| AC-2 | Red fixture: attempt-1 verdict `fail` → rework fires with `e2e_comments` in the implement attempt-2 context → red-attempt artifacts present → teardown after EVERY attempt → converge green OR exhaust→`escalate`→review (never a red path to `done`) | T9 |
| AC-3 | Green + red running simultaneously: two distinct `maister-run-<id>` compose projects, no name/port collisions, both fully torn down | T10 |
| AC-4 | Teardown survives interruption: script-level TERM (harness case 7) + system-level SIGTERM mid-test, timeout abort under group-kill, error paths | T-RED (script level), T11a/T11b (system level) |
| AC-5 | Docker-less host: probes fail actionably BEFORE any run work (`PRECONDITION` with hints) | T3 probes + T11c |
| AC-6 | Config errors: exit≠0 with actionable `[env-e2e:config]` message; platform side = run Failed | T-RED cases 1-3, 8 |
| AC-7 | Packaged script executes via `MAISTER_FLOW_DIR` on engine ≥ 3.3.0; the `:?` guard message names the floor on older engines | T0 tests + T8 |
| AC-8 | Web-tier secret sentinel is NOT visible inside containers | T-RED case 9 |
| AC-9 | Result contract: schema-valid JSON, verdict semantics per §4, populated `summary`/`e2e_comments`, both artifacts on every exit-0 path | T-RED 5/6/10 + T4 (schema materialization) |
| AC-10 | Static + release gates green (`validate:package-compatibility --mode release`); spec/README/docs complete and consistent | T4, TS3, T12, T13 |

## 10. Absence statements (verified)

- **No DB migration.** The engine version is a code constant
  (`web/lib/flows/engine-version.ts`); T0 touches no schema, no drizzle
  migration files, no journal entry.
- **No OpenAPI/AsyncAPI delta.** No HTTP surface or event is added or changed;
  `MAISTER_FLOW_DIR` is engine-internal child-env plumbing (not an
  operator-set env var — no `configuration.md` env-table row either).
- **No `maister.yaml` schema change**; the per-project config is a plain
  repo-root file owned by this package's convention.
- **No platform GC/sweeper change**; crash orphans are handled by the
  documented manual sweep (FR-13).

## 11. Self-check (TS3 spec consistency gate)

Executed 2026-07-31 against MAIster platform code (worktree
`xenodochial-keller-9142cd` @ main `fa31140d1` + TS2 docs) and this spec:

- [x] Every FR (FR-1…FR-14, NFR-1…3) is covered by ≥ 1 AC or an explicit
  harness case / verifier (FR-1,4,5,6,9 → AC-1/2/4/9; FR-2,3 → AC-1/3;
  FR-7 → AC-6; FR-8 → AC-5; FR-10 → AC-8; FR-11 → AC-7; FR-12 → AC-1 timing +
  §6 budget; FR-13 → AC-4 residual + README; FR-14 → AC-1/2/3 substrate;
  NFR-1 → T6 refactor guard; NFR-2 → harness log asserts; NFR-3 → AC-8).
- [x] Every AC (AC-1…AC-10) has a named verifier task (§9).
- [x] Verdict enum (`pass|fail`) ≡ decide-producible outcomes; every
  producible outcome is a declared transition key; `escalate` is
  onExhaustion-only (§3 invariant 3, `runner-graph.ts` guard).
- [x] `onExhaustion`/`resetTargets` syntax matches `config.schema.ts`
  `reworkSchema` and the ADR-118 exemplar in `docs/flow-dsl.md`.
- [x] Artifact-gate placement is consistent between §3 invariant 4, the
  platform produces-recording order, and the `aif-dev` exemplar; green-path
  promotion gating carried by `requiredFor` currency.
- [x] Edge-case inventory (§8) ⊇ the T-RED case list in the plan (10/10
  mapped, same numbering).
- [x] No contradiction found between this spec, platform ADR-154, and the
  `flow-dsl.md`/`flow-graph.md` deltas (child-env contract, scope v1 = node
  actions only, engine floor 3.3.0, timeout/group-kill semantics).
- [x] Absence statements verified by inspection: no `web/drizzle` migration
  touched; no `docs/api/*` delta; grep for new endpoints/events in the T0
  scope is empty.
- [x] Result-schema grammar statement matches `formSchemaSchema` +
  `validateStructuredOutput` (restricted grammar, openness by construction).
- [x] Corrections to the request text are each marked **[grounding]** with a
  platform citation (§2 FR-5/FR-6, §3 invariant 4, §4 grammar).

**Independent verification pass (adversarial, fresh-context agent,
2026-07-31):** all 14 grounding claims (check-node failure semantics,
commentsVar/vars injection, timeout+group-kill+4 MiB cap, run-dir produces
resolution + recording order, artifact_required currency-only semantics,
requiredFor readiness Check 1, decide routing + allow-list guard,
onExhaustion/resetTargets validation incl. forward-chain reachability,
formSchemaSchema grammar, ADR-153 allow-list, T0 seam shape, cross-doc
consistency, engine-sweep completeness, exemplar-precedented syntax) —
CONFIRMED against code with file:line evidence. Findings resolved: spec
status line reworded (was ahead of implementation); harness case 5 hardened
to stub-unfakeable asserts (tar contents + stub-marker absence — the T3
stub satisfies the bare artifact/JSON contract by design); the plan's
`additionalProperties: true` wording is superseded by §4 (the platform
grammar has no such keyword — openness is by construction). Known
intentional sequencing: the platform TS2 docs (ADR-154/3.3.0 "Implemented")
precede T0's code by one commit on the SAME branch — the branch merges as a
unit, per the plan's commit order.
