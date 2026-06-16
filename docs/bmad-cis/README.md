# BMAD Method — Creative Intelligence Suite (CIS) package — reference

The **[BMAD Creative Intelligence Suite](https://github.com/bmad-code-org/bmad-module-creative-intelligence-suite)**
as MAIster platform agents + a creative discovery flow. Package source:
[`packages/bmad-cis/`](../../packages/bmad-cis/) · quick-start:
[`packages/bmad-cis/README.md`](../../packages/bmad-cis/README.md).

- **Provenance:** BMAD CIS (MIT, © BMad Code, LLC). The 4 creative workflow
  skills are vendored verbatim from `…@v0.2.1` (`src/skills/*`); the 6 personas
  are re-authored from `src/skills/bmad-cis-agent-*/customize.toml`. License at
  `capability/reference/LICENSE.bmad`.
- **Pin:** package tag `bmad-cis/vX.Y.Z`; upstream CIS pinned to `v0.2.1`.

## The methodology

CIS is BMAD's creative front-end: brainstorming, design thinking, problem
solving, innovation strategy, storytelling, and presentation — a cast of six
specialists for the fuzzy front-end *before* requirements exist. In MAIster they
are platform agents, with a `cis-discovery` flow that chains three of them into
a phase-0 pipeline feeding the SDLC.

## Flow

`cis-discovery` (`compat.engine_min: 1.5.0`):

```
substrate → frame[quinn]      (bmad-cis-problem-solving   → docs/discovery/framing.md)
          → ideate[maya]      (bmad-cis-design-thinking   → docs/discovery/concepts.md)
          → synthesize[victor](bmad-cis-innovation-strategy → docs/planning-artifacts/discovery-brief.md)
          → 🚪 review (approve / rework→ideate) → done
```

- Typed artifacts chain `framing → concepts → discovery-brief` (`generic_file`).
- `synthesize` is gated by a `command_check`
  (`test -s docs/planning-artifacts/discovery-brief.md`).
- The brief lands in `docs/planning-artifacts/` precisely so the `bmm-plan` flow
  consumes it (committed-artifact handoff; live cross-package binding = Phase 2).

## Capability bundle

`capability/skills/*` vendors 4 CIS workflow skills (materialised into each
session's `.claude/skills/`). The 6 personas live at the package-root `agents/`
dir, auto-scanned into the catalog. `capability/reference/` is provenance only.

## Reconciliation

Same mapping as [`bmad-bmm`](../bmad-bmm/README.md#reconciliation-bmad-interactivity--maister-hitl):
agent activation/menu dropped (headless persona); per-step elicitation → the
`human` review gate; `_bmad/cis/config.yaml` written by the `substrate` `cli`
node; MAIster owns branch/merge/PR.

## Scope (v1)

1 flow (`cis-discovery`, the multi-persona phase-0). Carson (brainstorming) and
Caravaggio (presentation) have no vendored workflow skill — their method lives
in their persona body and they are standalone-only. Storyteller Sophia is
standalone (her `bmad-cis-storytelling` skill is vendored). Per-method flows and
live `cis-discovery → bmm-plan` wiring are Phase 2.
