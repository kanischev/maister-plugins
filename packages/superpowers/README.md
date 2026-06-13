# Superpowers Flow package

The **[Superpowers](https://github.com/obra/superpowers) methodology for
MAIster**. A self-contained plugin that wraps Jesse Vincent's superpowers
development workflow (brainstorm → plan → TDD-implement → verify → review →
finish, with systematic-debugging woven in) as MAIster flows backed by the
full vendored superpowers skills bundle.

This package is self-contained; nothing here imports from MAIster core.
Versioned by per-package git tags: `superpowers/vX.Y.Z` (see the repo root
README).

## Provenance

- **Framework**: superpowers — https://github.com/obra/superpowers (MIT,
  Jesse Vincent). All 14 skills are vendored under `capability/skills/`
  (upstream LICENSE kept at `capability/LICENSE.superpowers`).
- **Vendored upstream version**: `5.1.0` (recorded in
  `maister-package.yaml` `metadata.sources`).

## Flows

Four flows ship with this package, routed by what the incoming task is.

| flow id      | HITL gates | route_when                                                        |
| ------------ | ---------- | ---------------------------------------------------------------- |
| `sp-dev`     | 3          | A feature/enhancement/refactor to build end-to-end (brainstorm → design_review → plan → plan_review → implement → verify → code_review → review → finalize). |
| `sp-debug`   | 1          | A reported bug/regression/test-failure to fix at root cause (systematic-debugging loop). |
| `sp-plan`    | 2          | Produce a validated design spec + implementation plan, without building yet. |
| `sp-execute` | 1          | An approved plan already exists and needs building (executing-plans / subagent-driven). |

Flow sources live under `flows/<id>/flow.yaml`.

## Package layout

| Path                         | Purpose                                                             |
| ---------------------------- | ------------------------------------------------------------------ |
| `capability/skills/`         | The full superpowers skills bundle (all 14, vendored wholesale — `SKILL.md` + `references/` + subagent prompt templates). |
| `capability/LICENSE.superpowers` | Upstream MIT license (provenance).                             |
| `flows/<id>/flow.yaml`       | The 4 flow sources above.                                           |
| `flows/{dev,execute}/schemas/intake.json` | HITL intake form schema (TDD discipline + implementation strategy). |
| `setup.sh`                   | Inert no-op (see below).                                            |

There is **no `init` flow** (superpowers is zero-setup, unlike AIF), **no
`config/` template** (superpowers has no config-file analog), and **no
`capability/agents/`** — superpowers ships no named agent definitions; its
"subagents" are prompt templates *inside* the skill dirs (e.g.
`subagent-driven-development/implementer-prompt.md`), dispatched as
`general-purpose` Task agents. Vendoring the skills wholesale already includes
them.

## How MAIster consumes it

A consuming project's `maister.yaml` registers this package:

- **One shared `capability_imports` bundle** pointing at `capability/`. All
  four flows reuse the same vendored skills. MAIster's capability
  materialization copies the whole `capability/skills/` tree into each session
  worktree's `.claude/skills/` at launch (per ADR-043) — there is nothing to
  install. The `claude-agent-acp` adapter loads project `.claude/` (it sets
  `settingSources: ["user","project","local"]`), so the agent can invoke the
  skills via the Skill tool.
- **Four `flows[]` sources**, one per `flows/<id>/flow.yaml`.

```yaml
# maister.yaml (consumer)
packages:
  - id: superpowers
    source: github.com/<org>/maister-plugins
    version: superpowers/v1.0.0
    path: packages/superpowers
```

### MAIster ↔ superpowers reconciliation (baked into the flow prompts)

Superpowers is interactive and git-owning by design; MAIster is the opposite.
Every `ai_coding` node prompt carries a short execution contract that
reconciles the two:

- **No auto-trigger hook.** Natively, superpowers injects its
  `using-superpowers` bootstrap via a `SessionStart` hook. MAIster has no
  `hook` capability kind, so that bootstrap is **not** delivered. Each node
  prompt therefore names the exact skill(s) to use and restates the
  forcing-function ("invoke the skill, follow it exactly, use required
  sub-skills") inline. (`rule`-kind capabilities are **not** materialised into
  a claude session today — they are not a viable bootstrap channel.)
- **Interactivity → MAIster HITL.** `AskUserQuestion` is disabled in the
  adapter. Skills run non-interactively (best-judgment, assumptions recorded);
  approvals/refinements happen at the `human` review gates, whose comments are
  fed back to the rework target.
- **Git/worktree neutralised.** `using-git-worktrees` and
  `finishing-a-development-branch` would create worktrees / merge / push / open
  PRs. MAIster owns the worktree, branch, and promotion, so prompts forbid all
  of that — `finalize` uses `finishing-a-development-branch` only through its
  verify-tests + commit-locally ("Keep as-is") path.

### Implementation strategy + the subagent caveat

`sp-dev` and `sp-execute` expose an intake choice
`execution: [subagent-driven, inline]` (default **subagent-driven**, per
superpowers' own recommendation):

- **subagent-driven** → `subagent-driven-development`: fresh implementer
  subagent per task + two-stage (spec, then quality) review.
- **inline** → `executing-plans`: same-session execution.

The adapter exposes the Task tool and loads project `.claude/agents/`, so
nested dispatch *is available*; its live behaviour/cost in an ACP session is
not yet proven in CI. Every implement/execute prompt carries an **explicit
inline fallback**, so the node works even if dispatch is unavailable. A live
spike is recommended before leaning on subagent-driven at scale.

## Policies (all flows)

- Runner profile `claude-code`: `claude` adapter, `claude-opus-4-8`,
  `anthropic` provider.
- `compat.engine_min: 1.4.0` (typed artifacts + `retry_policy` +
  `session_policy`; `sp-plan` also uses an M29 `must_touch` mutation gate).
- `defaults.session_policy: resume` (one ACP session reused across nodes).
- `retry_policy` on every `ai_coding` node: auto-retry infra failures
  (`SPAWN`, `EXECUTOR_UNAVAILABLE`, `CHECKPOINT`, `ACP_PROTOCOL`), workspace
  rewound to the pre-attempt checkpoint.
- `verdict_calibration.confidence_min: 0.7` (folded into the advisory
  `ai_judgment` review gate; not on `sp-plan`, which has no AI judgment).
- Review rework offers `workspacePolicies: [keep, rewind-to-node-checkpoint]`;
  design/plan rework use `[keep]`; all `maxLoops: 3`.

## Gates

- **Review nodes** (`sp-dev`/`sp-debug`/`sp-execute`): blocking
  `artifact_required(impl-diff)` + advisory `ai_judgment` over the diff.
- **`finalize`**: blocking `command_check` — the tracked working tree must be
  clean (everything committed) before MAIster promotes.
- **`sp-plan` finalize**: blocking `artifact_required` with
  `must_touch: [docs/superpowers/**]` (records a `mutation_report`) + the
  clean-tree check.

## setup.sh

`setup.sh` is an **inert no-op**: it prints a one-line notice to stderr and
exits `0`. MAIster delivers the superpowers skills through capability
materialization, so there is nothing to install at flow-setup time.
