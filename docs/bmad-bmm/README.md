# BMAD Method — Core SDLC (BMM) package — reference

The **[BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD)** v6 BMM
module as MAIster flows + platform agents. Package source:
[`packages/bmad-bmm/`](../../packages/bmad-bmm/) · quick-start:
[`packages/bmad-bmm/README.md`](../../packages/bmad-bmm/README.md).

- **Provenance:** BMAD Method (MIT, © BMad Code, LLC). The BMM **workflow
  skills** are vendored verbatim from `BMAD-METHOD@v6.8.0`
  (`src/bmm-skills/*`); the six **personas** are re-authored as MAIster platform
  agents from each agent's `customize.toml`. License at
  `capability/reference/LICENSE.bmad`.
- **Pin:** package tag `bmad-bmm/vX.Y.Z`; upstream BMAD pinned to `v6.8.0`.

## The methodology

BMAD ("Breakthrough Method of Agile AI-Driven Development") runs delivery as a
cast of specialised agents across a four-phase SDLC:

```
1 analysis     → product brief / research              (Mary, Paige)
2 planning     → PRD, UX                                (John, Sally)
3 solutioning  → architecture, epics + stories         (Winston)
4 implementation → create story → dev (TDD) → review    (Amelia)
```

MAIster realises this as a **hybrid**: each persona is a platform agent
(`agents/<stem>.md`) bound to `ai_coding` nodes via `settings.agent`; the
phases are `bmm-*` flows with human review gates between artifacts.

## Flows

| flow | graph | HITL |
| ---- | ----- | ---- |
| `bmm-plan` | `substrate → brief[mary] → 🚪 → prd[john] → 🚪 → ux[sally] → architecture[winston] → 🚪 → epics[winston] → readiness` | 3 |
| `bmm-dev-story` | `substrate → create_story[amelia] → 🚪 → dev[amelia] → code_review[amelia] → 🚪(approve/rework/takeover) → done` (rework→`fix`→`code_review`; takeover→`code_review`) | 2 |
| `bmm-quick-dev` | `substrate → quick[amelia] → 🚪(approve/rework) → done` | 1 |

- **Typed artifacts** carry the evidence chain: `product-brief → prd-doc →
  architecture-doc → epics-doc` (plan); `story-doc → impl-diff` (dev-story);
  `impl-diff` (quick-dev). `impl-diff` is `requiredFor: [review, merge]`.
- **Gates:** `command_check` (`find … -size +0c`) enforces each planning doc was
  written; `ai_judgment` gates the implementation-readiness verdict and the code
  review; `artifact_required` refuses review without a current `impl-diff`.
- **Policies:** `compat.engine_min: 1.5.0` (settings.agent binding),
  `defaults.session_policy: resume`, per-node `retry_policy` on infra errors,
  `verdict_calibration.confidence_min: 0.7`, bounded rework (`maxLoops: 3`).

## Capability bundle

`capability/skills/*` vendors 26 BMM workflow skills (materialised into each
session worktree's `.claude/skills/` per the wholesale-copy rule in the
[packages index](../README.md#how-maister-materialises-a-capability-bundle-claude-adapter)).
The six platform agents live at the package-root `agents/` dir and are
auto-scanned into the platform agent catalog at install
(`web/lib/agents/registry.ts`). `capability/reference/` (LICENSE + the
`_bmad-substrate` config template) is stored for provenance only — **not**
materialised.

## Reconciliation (BMAD interactivity → MAIster HITL)

| BMAD upstream | MAIster |
| ------------- | ------- |
| Agent activation: greet + capability menu + wait for input | Platform-agent persona body; no greeting/menu (headless) |
| Per-document `<ask>` elicitation | `human` review gate (approve / rework) after each artifact |
| `npx bmad-method install` → full `_bmad/` tree | `substrate` `cli` node writes the minimal `_bmad/bmm/config.yaml` into the worktree |
| `resolve_customization.py` resolver | Omitted — skills fall back to reading the vendored `customize.toml` |
| `sprint-status.yaml` story board | In-worktree artifact only (board wiring = Phase 2) |
| Agent owns git (branches, commits) | MAIster owns branch/merge/PR; agents commit locally only |

## Iterations

`bmad-bmm` is Iteration 1 of the BMAD port. `bmad-tea` (Murat · Test Architect)
and `bmad-cis` (six creative personas) follow as sibling packages.
