# OpenSpec package — reference

The **[OpenSpec](https://github.com/Fission-AI/OpenSpec)** spec-driven workflow
as MAIster flows. Package source:
[`packages/openspec/`](../../packages/openspec/) · quick-start:
[`packages/openspec/README.md`](../../packages/openspec/README.md) · design
rationale: [`specs/`](specs/).

- **Provenance:** OpenSpec (MIT, Fission-AI). Driven at runtime via the
  `openspec` CLI (`@fission-ai/openspec@1.4.1`, installed by `setup.sh` / the
  `os-init` flow). `capability/reference/` vendors OpenSpec's schema/templates +
  the claude skills/commands `openspec init` scaffolds, as read-only provenance.
- **Pin:** package tag `openspec/vX.Y.Z`; OpenSpec CLI pinned to `1.4.1`.

## The methodology

OpenSpec is a lightweight spec layer: agree on *what* to build before code. The
loop is **Propose → Apply → Archive**:

```
propose  → openspec new change → write proposal.md / design.md / tasks.md / spec deltas
apply    → implement tasks.md against the proposal + spec deltas
archive  → fold spec deltas into openspec/specs/, move change to changes/archive/
```

The package splits this into four MAIster flows, inserting MAIster-native HITL
where OpenSpec's value demands human agreement (the proposal, before any code)
and where MAIster demands a review (the diff, before archiving/promotion).

## Flows

⛛ = `human` HITL gate · 🚦 = blocking gate · ▷ = advisory gate · ⚙ = `cli`/`check` node (no agent).

### `os-dev` — change end-to-end (2 HITL)

```
propose(ai) ──(change-proposal)──[🚦openspec validate]──→ ⛛proposal_review
   ↑──────────────────rework──────────────────────────────┘ │approve
   │                                                         ▼
   apply(ai) ──(impl-diff)──→ ⚙verify(openspec validate) ──→ code_review(ai) ──(ai_judgment)──→
   ⛛review[🚦artifact_required(impl-diff) · ▷ai_judgment]
      ├ approve  → ⚙archive(openspec archive+validate+commit)[🚦must_touch openspec/** · 🚦clean-tree] → done
      ├ rework   → fix(ai) → verify …          (loop, maxLoops 3)
      └ takeover → verify                        (re-validate the human's local edits)
```

### `os-propose` — proposal only (1 HITL)

```
propose(ai)[🚦validate · 🚦must_touch openspec/** · 🚦clean-tree] ──→ ⛛proposal_review
   ↑──────────────rework────────────────────────────────────────────┘ approve → done
```

### `os-apply` — build an existing change (1 HITL)

```
apply(ai) ──(impl-diff)──→ ⚙verify ──→ code_review(ai) ──→
⛛review[🚦artifact_required · ▷ai_judgment]
   ├ approve → ⚙archive[🚦must_touch openspec/** · 🚦clean-tree] → done
   ├ rework  → fix(ai) → verify   (loop, maxLoops 3)
   └ takeover → verify
```

### `os-init` — one-time ensure + scaffold (1 HITL)

```
⚙ensure(install openspec if absent) → init(ai: openspec init --tools claude + project.md)
  → ⛛review(approve) → ⚙commit[🚦must_touch openspec/** · 🚦clean-tree] → done
```

## Integration model — hybrid `cli` + `ai_coding`

OpenSpec is a CLI + an in-project `openspec/` base, not a skills library, and
ships **no MCP server**. The flows therefore drive the CLI, split by node type:

- **`cli` / `check` nodes** run the OpenSpec CLI directly via MAIster's runner
  (`bash -c`, host PATH) — **no agent, no permission HITL**. Used for the
  deterministic ops: `verify` (`openspec validate`), `archive`
  (`openspec archive -y && validate && git commit`), `os-init` `ensure`
  (install) + `commit`.
- **`ai_coding` nodes** are used only where an agent must *write* — `propose`,
  `apply`, `fix`, `code_review`. They carry `settings.permissionMode: allow` so
  the agent's file edits + CLI calls run unattended (HITL stays at the review
  gates). This is the one place the agent shells out to `openspec`.
- The flows use the **bare `openspec` binary**, not `/opsx:*` slash commands or
  `openspec-*` skills (those assume interactivity + were built for native Claude
  Code).

## Dependency on the `openspec` CLI (ADR-091 `requirements`)

This package is the first to need an **external CLI at runtime**, which drove a
core MAIster feature — per-flow `requirements` launch probes (ADR-091 in the
MAIster repo):

- `os-dev` / `os-propose` / `os-apply` declare
  `requirements: [{ name: "openspec CLI present", probe: "command -v openspec",
  hint: "run os-init first, or npm i -g @fission-ai/openspec@1.4.1" }]`. MAIster
  probes it **before** any worktree/session and refuses launch with a clean
  `PRECONDITION` if the CLI is absent — no late mid-run failure, no token spend.
- `os-init` requires only `npm` (it installs the CLI in its `ensure` node).
- **Install paths:** `os-init`'s `ensure` cli node (`command -v openspec ||
  npm i -g @fission-ai/openspec@1.4.1`, self-healing per run) and `setup.sh`
  (same, at package-install time, exec-trust gated). Run `os-init` once per
  project, then the other flows' requirement probe passes.

## MAIster ↔ OpenSpec reconciliation (inlined into prompts)

- **Non-interactive.** `AskUserQuestion` is disabled; prompts auto-select the
  single active change, derive change names, best-judgment; corrections via HITL
  rework comments. CLI calls use `--json` / `--no-interactive` / `-y` / `--force`.
- **Git/promotion owned by MAIster.** No worktree/branch creation, no
  merge/push/PR; commit locally only. Archive commits the folded specs; MAIster
  promotes.
- **spec-driven schema only.** `actionContext.mode: "workspace-planning"` → STOP.

## Policies & artifacts

- Runner `claude-code` (`claude` / `claude-opus-4-8` / `anthropic`);
  `compat.engine_min: 1.4.0`; `defaults.session_policy: resume`; `retry_policy`
  on every `ai_coding` node; `verdict_calibration.confidence_min: 0.7` on
  `os-dev`/`os-apply`.
- Artifacts: `change-proposal` (generic_file), `impl-diff` (diff, requiredFor
  `[review, merge]`), `ai-judgment` (ai_judgment), `*-mutation-report`.
- Gates: `propose` → `command_check openspec validate`; `verify` → `check`
  node; `review` → `artifact_required(impl-diff)` blocking + `ai_judgment`
  advisory; terminal → `must_touch [openspec/**]` (mutation_report) + clean-tree.

## Template-var safety (strict Mustache)

Only `{{ task.prompt }}` (always available) and `commentsVar`s on actual rework
targets are referenced — `{{ proposal_review_comments }}` in `propose`,
`{{ review_comments }}` in `fix` (both runner-seeded empty on first visit). No
intake forms.
