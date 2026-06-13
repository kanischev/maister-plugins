# AIF package — reference

The **[AI Factory](https://github.com/lee-to/ai-factory/tree/2.x) (AIF)**
workflows as MAIster flows, backed by a vendored AIF skills + subagents bundle.
Package source: [`packages/aif/`](../../packages/aif/) ·
quick-start: [`packages/aif/README.md`](../../packages/aif/README.md).

- **Provenance:** AI Factory `2.x` (Apache-2.0); skills + subagents vendored
  under `packages/aif/capability/`. Extracted from the MAIster repo
  (`plugins/aif @ maister@c104f66b`, 2026-06-12).
- **Pin:** git tag `aif/vX.Y.Z` (current line `aif/v2.0.0`).

## Flows

| flow id | Shape | route_when |
| ------- | ----- | ---------- |
| `aif-dev` | intake(form) → plan → improve → plan_review⛛ → implement → checks → code_review → review⛛ → commit; review rework → fix | A feature/enhancement/refactor with a clear spec. |
| `aif-bugfix` | fix → checks → code_review → review⛛ → commit; emits a self-improvement patch | A reported bug/error/regression. |
| `aif-evolve` | evolve → review⛛ → commit (mutation gate on `.ai-factory/**`,`.claude/**`) | Periodic: distill fix-patches into better skills. |
| `aif-roadmap` | roadmap → review⛛ → commit (mutation gate on `.ai-factory/**`) | A large/multi-milestone initiative needing a roadmap. |
| `aif-init` | setup → architecture → review⛛ → commit (mutation gate) | One-time: project not yet AIF-initialized. |

⛛ = `human` HITL gate. Each `ai_coding` node maps to an AIF slash-command skill
(`/aif-plan`, `/aif-implement`, `/aif-verify`, `/aif-review`, `/aif-fix`,
`/aif-commit`, `/aif-evolve`, `/aif-roadmap`, `/aif`, `/aif-architecture`).

## Capability bundle

`capability/` carries the vendored AIF **skills** (`skills/aif-*/SKILL.md` +
`references/` + `tests/` + `templates/` + `scripts/`) and **subagents**
(`agents/*.md` — the loop-*, plan-*, implement-* orchestration agents AIF
skills dispatch via the Task tool). MAIster copies the whole tree into each
session worktree's `.claude/` at launch.

A consuming project registers it as one shared `capability_imports` bundle
(reused by all five flows) plus five `flows[]` sources.

## Reconciliation with MAIster

- **Git ownership.** AIF ships a default `.ai-factory/config.yaml`
  (`config/ai-factory.config.yaml`) with MAIster-compat overrides — most
  importantly **`git.create_branches: false`**: MAIster owns the worktree and
  branch, so AIF works git-aware but must not create its own branch. All
  committing is deferred to `/aif-commit` on the terminal `commit` node.
- **Interactivity → HITL.** AIF's questions/approvals are delivered by
  MAIster-native HITL (`form` intake + `human` review nodes), not the AIF
  `AskUserQuestion` tool (disabled in the adapter). `ai_coding` prompts run
  non-interactively ("do NOT ask the user; apply best-judgment").
- **Init ordering.** Run `aif-init` first if the project has no
  `.ai-factory/DESCRIPTION.md`; the other flows assume an initialized AIF
  project.

## Policies & gates

- Runner `claude-code` (`claude` / `claude-opus-4-8` / `anthropic`);
  `compat.engine_min: 1.4.0`; `defaults.session_policy: resume`.
- `retry_policy` on every `ai_coding` node (auto-retry `SPAWN`,
  `EXECUTOR_UNAVAILABLE`, `CHECKPOINT`, `ACP_PROTOCOL`;
  `rewind-to-node-checkpoint`).
- `verdict_calibration.confidence_min: 0.7` (advisory `ai_judgment` review
  gate). Review rework offers `[keep, rewind-to-node-checkpoint]`, `maxLoops:
  3`; `review` adds a `takeover` decision (returns at `checks`).
- **Artifacts:** `impl-diff` (diff, requiredFor `[review, merge]`),
  `aif-gate-result` (test_report), `ai-judgment` (ai_judgment).
- **Gates:** `review` — blocking `artifact_required(impl-diff)` + advisory
  `ai_judgment`; `commit` — blocking `command_check` (clean tree + conventional
  last commit); meta-flow commit nodes add `artifact_required` `must_touch`
  mutation gates (`mutation_report`).
