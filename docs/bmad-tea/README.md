# BMAD Method — Test Architect (TEA) package — reference

The **[BMAD Test Architect](https://github.com/bmad-code-org/bmad-method-test-architecture-enterprise)**
enterprise module as MAIster flows + the Murat platform agent. Package source:
[`packages/bmad-tea/`](../../packages/bmad-tea/) · quick-start:
[`packages/bmad-tea/README.md`](../../packages/bmad-tea/README.md).

- **Provenance:** BMAD Test Architect (MIT, © BMad Code, LLC). The 9 testarch
  workflow skills are vendored verbatim from `…@v1.19.0`
  (`src/workflows/testarch/*`); Murat is re-authored from
  `src/agents/bmad-tea/customize.toml`. License at
  `capability/reference/LICENSE.bmad`.
- **Pin:** package tag `bmad-tea/vX.Y.Z`; upstream TEA pinned to `v1.19.0`.

## The methodology

TEA is BMAD's quality discipline: risk-based testing depth, API-first test
levels, deterministic fixtures, and data-backed quality gates. One persona —
**Murat** (🧪) — owns it, driving discrete workflows for test design,
automation, NFR audit, traceability, and review.

## Flows

| flow | output | graph |
| ---- | ------ | ----- |
| `tea-test-design` | doc | `substrate → work[murat] → 🚪 → done` |
| `tea-automate` | code (`impl-diff`) | `substrate → work[murat] → 🚪(artifact_required impl-diff) → done` |
| `tea-nfr` | doc | `substrate → work[murat] → 🚪 → done` |
| `tea-trace` | doc | `substrate → work[murat] → 🚪 → done` |
| `tea-test-review` | doc | `substrate → work[murat] → 🚪 → done` |

- Doc flows enforce production with a `command_check`
  (`find docs/test-artifacts -type f -size +0c`); `tea-automate` produces a
  `diff` (`requiredFor: [review, merge]`) gated by `artifact_required` +
  an advisory `ai_judgment` on the review node.
- Policies: `compat.engine_min: 1.5.0`, `defaults.session_policy: resume`,
  per-node `retry_policy`, bounded rework (`maxLoops: 3`).

## Capability bundle

`capability/skills/*` vendors 9 testarch workflow skills (materialised into each
session's `.claude/skills/`). Murat lives at the package-root `agents/` dir,
auto-scanned into the platform agent catalog. `capability/reference/` (LICENSE +
`_bmad-substrate/config.yaml.template`) is provenance only.

## Reconciliation

Same mapping as [`bmad-bmm`](../bmad-bmm/README.md#reconciliation-bmad-interactivity--maister-hitl):
agent activation/menu dropped (headless persona); per-step elicitation → `human`
review gate; `_bmad/tea/config.yaml` written by the `substrate` `cli` node (not
`npx bmad-method install`); the Pact/PactFlow MCP (`tea_pact_mcp`) is off by
default; MAIster owns branch/merge/PR.

## Scope (v1)

5 flows for the distinct deliverables (design / automate / nfr / trace /
review). `atdd`, `framework`, `ci`, `teach-me-testing` skills are reachable via
Murat standalone but have no dedicated flow yet. TEA-into-`bmm-dev-story`
(cross-package node binding) = Phase 2.
