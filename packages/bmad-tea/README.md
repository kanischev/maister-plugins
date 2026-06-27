# BMAD Method — Test Architect (TEA) Flow package

The **[BMAD Test Architect](https://github.com/bmad-code-org/bmad-method-test-architecture-enterprise)
enterprise module for MAIster**. Murat — Master Test Architect — ships as a
platform agent driving risk-based testing, automation, NFR audit, traceability +
quality gates, and test review.

Versioned by per-package git tags: `bmad-tea/vX.Y.Z`. The **upstream TEA version
is pinned to `v1.19.0`** (recorded in `maister-package.yaml` `metadata.sources`);
independent of this package's own tag.

## What changed in `bmad-tea/v1.1.0`

Adopts the MAIster **flow engine 2.0.0** baseline (M42 / ADR-114 — unified
runner config + first-class sessions):

- `compat.engine_min: 2.0.0` on all five flows.
- Each TEA flow is a single Murat-driven phase plus a human review gate, so all
  five keep one reused `default` session (engine-baseline bump only) — there is
  no multi-phase context to reset.

## Provenance

- **Framework**: BMAD Test Architect (MIT, © BMad Code, LLC). License vendored
  at `capability/reference/LICENSE.bmad`.
- `capability/skills/*` vendors the **9 testarch workflow skills** verbatim from
  `bmad-method-test-architecture-enterprise@v1.19.0` `src/workflows/testarch/*`.
- `agents/murat-test-architect.md` is a MAIster platform agent whose persona is
  **derived** from `src/agents/bmad-tea/customize.toml`.

## Platform agent

| stem | persona |
| ---- | ------- |
| `murat-test-architect` | 🧪 Murat · Master Test Architect and Quality Advisor — `mode: session`, `triggers: [flow, manual]` |

Murat drives all 9 vendored skills:
`bmad-testarch-{test-design,automate,atdd,nfr,trace,test-review,framework,ci}`
and `bmad-teach-me-testing`.

## Flows

| flow id | output | HITL | route_when |
| ------- | ------ | ---- | ---------- |
| `tea-test-design` | doc | 1 | Plan testing: risk assessment, NFR planning, coverage strategy. |
| `tea-automate` | code | 1 | Generate prioritized API/E2E tests + fixtures for a story/feature. |
| `tea-nfr` | doc | 1 | Audit non-functional-requirement evidence + recommend actions. |
| `tea-trace` | doc | 1 | Map requirements to tests + make the PASS/CONCERNS/FAIL/WAIVED gate decision. |
| `tea-test-review` | doc | 1 | Review the quality of existing tests against best practices. |

Each flow: `substrate → work[murat] → 🚪 review (approve/rework) → done`.
Doc flows write to `docs/test-artifacts/`; `tea-automate` produces a code `diff`
for review + promotion.

The `atdd`, `framework`, `ci`, and `teach-me-testing` skills are **not** dedicated
flows in v1 — they are reachable by launching Murat standalone (all 9 skills are
materialized into the session).

## How it works

Same hybrid model as `bmad-bmm`: persona = platform agent bound to `ai_coding`
nodes via `settings.agent: bmad-tea:murat-test-architect` (engine `1.5.0`); the
process = a vendored testarch skill driven non-interactively; interactivity →
`human` review gate. Each flow opens with a `cli` `substrate` node that writes
the minimal `_bmad/tea/config.yaml` into the worktree (canonical template at
`capability/reference/_bmad-substrate/config.yaml.template`). No `setup.sh`, no
`requirements` probe (no external binary — the optional Pact MCP is off by
default). MAIster owns git + promotion.

## Iterations

`bmad-tea` is Iteration 2 of the BMAD port (after `bmad-bmm`). Wiring a TEA
quality node into `bmm-dev-story` (cross-package `settings.agent`) is a Phase-2
enhancement.

## Install (local dev)

```bash
pnpm install-package --source /abs/path/to/maister-plugins/packages/bmad-tea \
  --version local-dev --project <slug>
```
