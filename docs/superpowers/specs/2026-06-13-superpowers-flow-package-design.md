# Superpowers flow package — design spec

**Date:** 2026-06-13 · **Status:** implemented (v1.0.0) · **Author:** brainstormed with the human partner

## Problem

MAIster has one flow package — `aif` ([AI Factory](https://github.com/lee-to/ai-factory)).
We want a second, analogous, project-pluggable package wrapping the
[obra/superpowers](https://github.com/obra/superpowers) methodology: assemble
MAIster flows that drive superpowers' skills/tools, with elaborate coding-node
prompts, gates, correctly-placed HITL, and recommended policies — the same shape
as the AIF package, in the same repo (`maister-plugins`).

Superpowers is a **methodology**, not a set of slash commands: 14 skills that
auto-trigger to enforce brainstorm → plan → TDD-implement → verify → review →
finish, with systematic-debugging woven in. Two impedance mismatches with
MAIster have to be solved:

1. **Auto-trigger depends on a SessionStart hook MAIster can't deliver.**
2. **Superpowers is interactive and git-owning; MAIster is non-interactive and
   owns the worktree + promotion.**

## Approaches considered

- **A. One flagship `dev` flow.** Minimal; but superpowers' distinct strengths
  (systematic-debugging; plan-only; execute-existing-plan) collapse into inline
  branches and lose their natural entry points.
- **B. Dev + Debug (2 flows).** Covers the two most common task types.
- **C. Full suite (4 flows) — CHOSEN.** `sp-dev`, `sp-debug`, `sp-plan`,
  `sp-execute`. Mirrors AIF's breadth (5 flows), and each flow maps to a
  distinct superpowers entry point and skill set. The human partner chose the
  full set.

For skill triggering: **explicit-in-prompts + bootstrap** was chosen over
explicit-only or auto-trigger-only. (The bootstrap channel changed during
verification — see below.) For vendoring: **all 14 skills + subagent prompt
templates**, wholesale, from the local cache `obra/superpowers@5.1.0` (MIT). For
HITL: **full ceremony (3 gates)** in `sp-dev`, faithful to superpowers'
approval-heavy philosophy.

## Verified mechanism (the load-bearing findings)

Read from MAIster `web/lib/capabilities/*` + the
`@agentclientprotocol/claude-agent-acp@0.37.0` adapter source:

| Question | Finding | Consequence for the design |
| -------- | ------- | -------------------------- |
| Do vendored skills reach the agent? | ✅ `copyBundleArtifactsToWorktree` copies `capability/skills/*` → `<wt>/.claude/skills/*` wholesale at launch (per-project, **not** gated on `settings.skills`). | Vendor skills under `capability/skills/`; don't over-engineer `settings.skills` for delivery. |
| Are project `.claude/` skills/agents loaded? | ✅ adapter sets `settingSources: ["user","project","local"]`; system preset `claude_code`. | Skill tool + Task tool both available. |
| Is the SessionStart bootstrap delivered? | ❌ MAIster has no `hook` capability kind; supervisor spawns the adapter without hooks. | Inline the `using-superpowers` forcing-function into each node prompt. |
| Can a `rule` capability carry the bootstrap? | ❌ `rule` is never written into a claude session (no `CLAUDE.md`/context channel; only an advisory sidecar the agent never opens). | Do **not** ship the bootstrap as a rule — inline it. |
| Is `AskUserQuestion` available? | ❌ `disallowedTools: ["AskUserQuestion"]`. | All interactivity via MAIster HITL; skills run non-interactively. |
| Is nested subagent dispatch available? | ⚠️ Capability present (Task tool exposed, `.claude/agents/` loaded, no gating) but live behaviour/cost unproven in CI. | Default `subagent-driven`, but ship an explicit inline fallback + recommend a spike. |

This overturned the original "bootstrap-rule" plan: the same effect is delivered
by **inlining** a compact execution contract into every `ai_coding` prompt.

## Design

A self-contained package `packages/superpowers/`:

```
maister-package.yaml   name: superpowers; flows[4]; capabilities[superpowers-bundle → capability]; mcps:[]
setup.sh               inert no-op
README.md              quick-start
flows/{dev,debug,plan,execute}/flow.yaml
flows/{dev,execute}/schemas/intake.json   (tdd, execution)
capability/skills/<14 superpowers skills, vendored wholesale>
capability/LICENSE.superpowers            (upstream MIT)
```

Deliberate omissions: no `init` flow (superpowers is zero-setup), no `config/`
template (no config-file analog), no `capability/agents/` (superpowers ships no
named agent defs; subagent prompts live inside skill dirs).

**Flow shapes, gates, HITL, policies:** see
[`docs/superpowers/README.md`](../README.md). Summary: `sp-dev` (3 HITL:
design/plan/review), `sp-debug` (1 HITL, systematic-debugging loop), `sp-plan`
(2 HITL, planning-only, `must_touch` docs gate), `sp-execute` (1 HITL, runs an
existing plan). All flows: `claude-opus-4-8` / `anthropic`,
`compat.engine_min: 1.4.0`, `session_policy: resume`, `retry_policy` on every
`ai_coding` node, advisory `ai_judgment` + blocking `artifact_required(impl-diff)`
on review nodes, blocking clean-tree `command_check` on `finalize`.

**Reconciliation (inlined execution contract):** no-hook → inline
forcing-function; interactivity → HITL; git/worktree/promotion neutralised;
per-skill next-skill hand-offs neutralised so each node stays one-phase. See the
reference doc for the exact contract.

### Decisions log

1. Flows: full suite of 4 (`sp-*` ids — short, package shown separately in UI).
2. Triggering: explicit-in-prompts **+ inlined bootstrap** (rule channel proven
   inert).
3. Vendoring: all 14 skills + subagent templates, wholesale, from
   `obra/superpowers@5.1.0`.
4. HITL: 3 gates in `sp-dev`.
5. Implementation default: `subagent-driven` (intake-selectable), with inline
   fallback baked into prompts.
6. Package tag: `superpowers/v1.0.0`; upstream `5.1.0` recorded in
   `metadata.sources`.

## Risks & open follow-ups

- **Nested subagent dispatch (⚠️).** Available but unproven live. Mitigated by
  the inline fallback. **Follow-up:** spike a real `sp-dev`/`sp-execute` run in
  `subagent-driven` mode and confirm dispatch + cost before relying on it.
- **Inline-bootstrap efficacy.** Whether the inlined forcing-function makes
  nested sub-skills cross-trigger as reliably as the native hook is unverified —
  confirm during the spike.
- **Component-version metadata.** Upstream version is recorded only in
  `metadata.sources` prose today; a first-class "vendored component versions"
  field across packages is a future idea (noted by the human partner).
- **`must_touch` engine floor.** `sp-plan` uses the M29 mutation gate
  (≥ 1.3.0); pinned at 1.4.0 like the rest.

## Verification done

- All four `flow.yaml` `name`s equal their `maister-package.yaml flows[].id`
  (`sp-dev`/`sp-debug`/`sp-plan`/`sp-execute`).
- Every templated var exists at its node (intake vars only on intake-bearing
  flows; `commentsVar`s only on rework-target nodes — strict-mode safe).
- All 14 skills + subagent templates present under `capability/skills/`.
- Artifact/gate/rework wiring mirrors the proven AIF package.
