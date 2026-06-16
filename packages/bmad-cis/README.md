# BMAD Method — Creative Intelligence Suite (CIS) Flow package

The **[BMAD Creative Intelligence Suite](https://github.com/bmad-code-org/bmad-module-creative-intelligence-suite)
for MAIster**. Six creative personas as platform agents, plus a multi-persona
**creative discovery** flow that runs *before* the SDLC and hands a brief to
`bmm-plan`.

Versioned by per-package git tags: `bmad-cis/vX.Y.Z`. The **upstream CIS version
is pinned to `v0.2.1`** (recorded in `maister-package.yaml` `metadata.sources`).

## Provenance

- **Framework**: BMAD Creative Intelligence Suite (MIT, © BMad Code, LLC).
  License vendored at `capability/reference/LICENSE.bmad`.
- `capability/skills/*` vendors the **4 creative workflow skills**
  (`bmad-cis-{design-thinking,innovation-strategy,problem-solving,storytelling}`)
  from `…@v0.2.1` `src/skills/*`.
- `agents/*.md` are MAIster platform agents whose personas are **derived** from
  each CIS agent's `customize.toml`.

## Platform agents (the creative cast)

| stem | persona | vendored skill |
| ---- | ------- | -------------- |
| `quinn-problem-solver` | 🔬 Dr. Quinn · Master Problem Solver | `bmad-cis-problem-solving` |
| `maya-design-thinking` | 🎨 Maya · Design Thinking Maestro | `bmad-cis-design-thinking` |
| `victor-innovation` | ⚡ Victor · Disruptive Innovation Oracle | `bmad-cis-innovation-strategy` |
| `sophia-storyteller` | 📖 Sophia · Master Storyteller | `bmad-cis-storytelling` |
| `carson-brainstorming` | 🧠 Carson · Elite Brainstorming Specialist | — (method in persona body) |
| `caravaggio-presentation` | 🎬 Caravaggio · Visual Communication Expert | — (method in persona body) |

Carson and Caravaggio have no dedicated upstream workflow skill — their craft
lives in their persona body; they are standalone-only in v1.

## Flow

| flow id | HITL | route_when |
| ------- | ---- | ---------- |
| `cis-discovery` | 1 | Explore a fuzzy problem/opportunity before planning. |

```
substrate → frame[quinn] → ideate[maya] → synthesize[victor] → 🚪 review (approve/rework) → done
```

`synthesize` writes the discovery brief to `docs/planning-artifacts/discovery-brief.md`,
so the `bmm-plan` flow (package `bmad-bmm`) picks it up as the seed for the
product brief — a committed-artifact handoff (no live cross-package binding in
v1).

## How it works

Same hybrid model as `bmad-bmm` / `bmad-tea`: each persona is a platform agent
bound to an `ai_coding` node via `settings.agent: bmad-cis:<stem>` (engine
`1.5.0`); the process = a vendored CIS skill driven non-interactively;
interactivity → the `human` review gate. The `substrate` `cli` node writes the
minimal `_bmad/cis/config.yaml`. No `setup.sh`, no `requirements` probe. MAIster
owns git + promotion.

## Iterations

`bmad-cis` is Iteration 3 of the BMAD port (after `bmad-bmm`, `bmad-tea`). Live
cross-package wiring (`cis-discovery` → `bmm-plan`) is Phase 2.

## Install (local dev)

```bash
pnpm install-package --source /abs/path/to/maister-plugins/packages/bmad-cis \
  --version local-dev --project <slug>
```
