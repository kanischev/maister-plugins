# Superpowers package — reference

The **[obra/superpowers](https://github.com/obra/superpowers)** development
methodology as MAIster flows. Package source:
[`packages/superpowers/`](../../packages/superpowers/) · quick-start:
[`packages/superpowers/README.md`](../../packages/superpowers/README.md) ·
design rationale: [`specs/`](specs/).

- **Provenance:** superpowers (MIT, Jesse Vincent); all 14 skills vendored
  under `packages/superpowers/capability/skills/`.
- **Vendored upstream version:** `5.1.0`.
- **Pin:** git tag `superpowers/vX.Y.Z` (current line `superpowers/v1.0.0`).

## The methodology

Superpowers is one coherent workflow expressed as auto-triggering skills:

```
brainstorming → writing-plans → (subagent-driven-development | executing-plans)
              → test-driven-development → verification-before-completion
              → requesting/receiving-code-review → finishing-a-development-branch
  with systematic-debugging woven in wherever a bug appears,
  and using-git-worktrees for isolation.
```

This package splits that single pipeline into four MAIster flows by **entry
point** (task type), and inserts MAIster-native HITL gates at the points where
superpowers natively asks its "human partner" to approve.

## Vendored skills (all 14)

| Skill | Used by node(s) |
| ----- | --------------- |
| `using-superpowers` | (reference; its forcing-function is inlined into prompts) |
| `brainstorming` | `brainstorm` (sp-dev, sp-plan) |
| `writing-plans` | `plan` (sp-dev, sp-plan) |
| `subagent-driven-development` | `implement`/`execute` (subagent-driven mode) |
| `executing-plans` | `implement`/`execute` (inline mode) |
| `test-driven-development` | every code-producing node |
| `systematic-debugging` | `debug` (sp-debug), `fix`, failed `verify` |
| `verification-before-completion` | `verify`, `finalize` |
| `requesting-code-review` | `code_review` |
| `receiving-code-review` | `fix` |
| `finishing-a-development-branch` | `finalize` (neutralised) |
| `using-git-worktrees` | (reference; MAIster owns isolation — not a node) |
| `dispatching-parallel-agents` | (reference; available to implement nodes) |
| `writing-skills` | (reference; available when a task is skill-authoring) |

Subagent **prompt templates** ride inside the skill dirs
(`subagent-driven-development/{implementer,spec-reviewer,code-quality-reviewer}-prompt.md`,
`requesting-code-review/code-reviewer.md`) and are referenced by path in the
node prompts.

## Flows

⛛ = `human` HITL gate · 🚦 = blocking gate · �÷ = advisory gate.

### `sp-dev` — full methodology (3 HITL)

```
intake(form: tdd, execution)
  → brainstorm ──(design-spec)──→ ⛛design_review ──approve──→ plan
       ↑───────────────────────────rework──────────────────────┘
  plan ──(plan-doc)──→ ⛛plan_review ──approve──→ implement
       ↑──────────────rework─────────┘
  implement ──(impl-diff)──→ verify ──(test_report)──→ code_review ──(ai_judgment)──→
  ⛛review[🚦artifact_required(impl-diff) · ▷ai_judgment]
     ├ approve  → finalize[🚦clean-tree] → done
     ├ rework   → fix → verify …            (loop, maxLoops 3)
     └ takeover → verify                     (re-validate human's local edits)
```

`intake.execution` picks `subagent-driven` (default) vs `inline`; `intake.tdd`
picks `strict` vs `pragmatic`. `brainstorm`/`plan` rework use `[keep]`; `review`
rework offers `[keep, rewind-to-node-checkpoint]`.

### `sp-debug` — root-cause loop (1 HITL)

```
debug (systematic-debugging: root cause → failing repro test → single fix)
  ──(impl-diff)──→ verify ──→ code_review ──→
  ⛛review[🚦artifact_required · ▷ai_judgment]
     ├ approve → finalize[🚦clean-tree] → done
     ├ rework  → debug          (loop, maxLoops 3)
     └ takeover → verify
```

### `sp-plan` — design + plan only (2 HITL)

```
brainstorm ──(design-spec)──→ ⛛design_review ──approve──→ plan
plan ──(plan-doc)──→ ⛛plan_review ──approve──→ finalize → done
finalize gates: 🚦artifact_required must_touch[docs/superpowers/**] (mutation_report) · 🚦clean-tree
```

No implementation; produces the committed spec + plan for a later `sp-execute`.

### `sp-execute` — build an existing plan (1 HITL)

```
intake(form: tdd, execution)
  → execute (executing-plans | subagent-driven + TDD)
  ──(impl-diff)──→ verify ──→ code_review ──→
  ⛛review[🚦artifact_required · ▷ai_judgment]
     ├ approve → finalize[🚦clean-tree] → done
     ├ rework  → fix → verify   (loop, maxLoops 3)
     └ takeover → verify
```

## How the upstream framework is reconciled with MAIster

Superpowers is interactive and git-owning; MAIster runs agents
non-interactively in a worktree it owns and promotes itself. The reconciliation
lives in a short **execution contract** prepended to every `ai_coding` prompt:

1. **No SessionStart hook.** Natively, superpowers injects its
   `using-superpowers` bootstrap (the "invoke skills even on a 1% chance"
   forcing-function) via a `SessionStart` hook in `hooks/hooks.json`. **MAIster
   has no `hook` capability kind**, so the supervisor spawns `claude-agent-acp`
   without it — the bootstrap is never delivered. Each node prompt therefore
   (a) names the exact skill(s) to invoke, and (b) restates the forcing-function
   inline so nested sub-skills (TDD ↔ debugging ↔ verification) still
   cross-trigger within the node.
2. **`rule` capabilities are inert for claude.** A vendored `rule` is *not*
   written into the session (no `CLAUDE.md`/`AGENTS.md`/context channel; it only
   appears in an advisory `.maister/.../instructions.md` the agent never opens).
   So the bootstrap is inlined into prompts, **not** shipped as a rule.
3. **Interactivity → MAIster HITL.** `AskUserQuestion` is disabled in the
   adapter (`disallowedTools: ["AskUserQuestion"]`). Skills run non-interactively
   (best-judgment, assumptions recorded in the artifact); approvals and
   refinements happen at the `human` review gates, whose comments flow back to
   the rework target via the node's `commentsVar`.
4. **Git/worktree/promotion neutralised.** `using-git-worktrees` and
   `finishing-a-development-branch` would create worktrees / merge / push / open
   PRs. Prompts forbid all of it; `finalize` uses
   `finishing-a-development-branch` only through its verify-tests +
   commit-locally ("Keep as-is") path, and a 🚦`command_check` asserts the
   tracked tree is clean before MAIster promotes.

Each skill's built-in **hand-off to the next skill** is also neutralised so a
node stays scoped to one phase: `brainstorm` stops after the spec (does not run
`writing-plans`); `plan` stops after the plan (does not offer execution);
`implement`/`execute` stop after the work (does not run
`finishing-a-development-branch`).

## Subagent dispatch — status

`subagent-driven-development` and `requesting-code-review` dispatch nested
`general-purpose` subagents via the Task tool. Static evidence that this is
**available** in a MAIster session:

- the adapter sets `settingSources: ["user","project","local"]` → project
  `.claude/agents/` is loaded;
- the `claude_code` system preset exposes the Task tool, and only
  `AskUserQuestion` is force-disallowed;
- the supervisor adds no `--agents`/tool gating.

Live behaviour and cost inside an ACP session are **not yet proven in CI**, so
every `implement`/`execute`/`code_review` prompt carries an **explicit inline
fallback** (use `executing-plans` / self-review with the same rubric if dispatch
is unavailable). Recommended follow-up: a live spike before relying on
`subagent-driven` at scale.

## Policies & artifacts

- Runner `claude-code` (`claude` / `claude-opus-4-8` / `anthropic`).
- `compat.engine_min: 1.4.0` (typed artifacts + `retry_policy` +
  `session_policy`; `sp-plan` also uses an M29 `must_touch` mutation gate, ≥
  1.3.0).
- `defaults.session_policy: resume`; `retry_policy` on every `ai_coding` node.
- `verdict_calibration.confidence_min: 0.7` (advisory `ai_judgment` review gate;
  omitted on `sp-plan`).
- Artifacts: `design-spec`/`plan-doc` (generic_file), `impl-diff` (diff,
  requiredFor `[review, merge]`), `sp-gate-result` (test_report), `ai-judgment`
  (ai_judgment), `*-mutation-report` (sp-plan).

## Templating notes (strict mode)

Mustache strict — an undefined var throws `CONFIG`. The package only references
vars that exist at each node:

- `{{ task.prompt }}` — always available.
- `{{ steps.intake.vars.tdd | execution }}` — only on flows with an `intake`
  form node (`sp-dev`, `sp-execute`).
- `{{ <commentsVar> }}` — only on nodes that are an actual **rework target**
  (runner-seeds them empty on the first visit): `brainstorm`
  (`design_review_comments`), `plan` (`plan_review_comments`), `fix`/`debug`
  (`review_comments`). Entry-only nodes (`implement`, `execute`) never reference
  a comments var.
