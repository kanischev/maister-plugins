# BMAD Method — Core SDLC (BMM) Flow package

The **[BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) v6 BMM module
for MAIster**. Brings BMAD's full agile SDLC — **analysis → planning →
solutioning → implementation** — into MAIster as platform agents bound to
gated flows.

Versioned by per-package git tags: `bmad-bmm/vX.Y.Z`. The **upstream BMAD
Method version is pinned to `v6.8.0`** (recorded in `maister-package.yaml`
`metadata.sources` and below); it is independent of this package's own tag.

## What changed in `bmad-bmm/v1.1.0`

Adopts the MAIster **flow engine 2.0.0** baseline (M42 / ADR-114 — unified
runner config + first-class sessions). Each persona now runs in its OWN session,
so one persona's context never bleeds into the next:

- `compat.engine_min: 2.0.0` on all three flows.
- **`bmm-plan`** — Mary (`analyst`), John (`pm`), Sally (`ux`), and Winston
  (`architecture` — architecture + epics + readiness share one continuous
  session). Review reworks keep `resume`, so a persona retains its own prior
  draft + the reviewer's critique on a redo.
- **`bmm-dev-story`** — Amelia drives every node, but each phase runs in its own
  session: story authoring (`default`), implementation (`dev`), fresh-eyes
  `code_review`, and `fix`. The `review → fix` rework re-enters `fix` fresh each
  iteration (`session_policy: new_session`).
- Every session inherits the flow's one `claude-code` runner (the persona is the
  `settings.agent` body, the host model is unchanged); state flows through the
  typed planning / implementation artifacts.
- `bmm-quick-dev` keeps a single reused `default` session (engine-baseline bump
  only).

## Provenance

- **Framework**: BMAD Method — https://github.com/bmad-code-org/BMAD-METHOD
  (MIT, © BMad Code, LLC). License vendored at
  `capability/reference/LICENSE.bmad`.
- `capability/skills/*` vendors the BMM **workflow skills** verbatim from
  `BMAD-METHOD@v6.8.0` `src/bmm-skills/{1-analysis,2-plan-workflows,3-solutioning,4-implementation}`
  (the `bmad-agent-*` persona dirs are excluded — they become platform agents).
- `agents/*.md` are MAIster platform agents whose personas are **derived** from
  each BMM agent's `customize.toml` (identity / principles / communication
  style), rewritten for MAIster's non-interactive, gate-HITL execution model.

## Platform agents (the BMAD cast)

Six personas ship as `agents/<stem>.md`, each `mode: session`,
`triggers: [flow, manual]` — bound to flow nodes via `settings.agent` AND
launchable standalone from the board.

| stem | persona | phase |
| ---- | ------- | ----- |
| `mary-analyst` | 📊 Mary · Business Analyst | analysis |
| `paige-tech-writer` | 📚 Paige · Technical Writer | analysis |
| `john-pm` | 📋 John · Product Manager | planning |
| `sally-ux` | 🎨 Sally · UX Designer | planning |
| `winston-architect` | 🏗️ Winston · System Architect | solutioning |
| `amelia-dev` | 💻 Amelia · Senior Software Engineer | implementation |

## Flows

| flow id | HITL | route_when |
| ------- | ---- | ---------- |
| `bmm-plan` | 3 | Plan a new feature/product end-to-end: brief (Mary) → **review** → PRD (John) → **review** → UX (Sally) → architecture (Winston) → **review** → epics+stories → readiness. |
| `bmm-dev-story` | 2 | Implement the next/specified story: create story (Amelia) → **review** → dev (test-first) → code review → **review** (approve/rework/takeover). |
| `bmm-quick-dev` | 1 | Implement a small, well-scoped change end-to-end without the full story cycle. |

`bmm-plan` produces planning **documents** under `docs/planning-artifacts/`;
`bmm-dev-story` / `bmm-quick-dev` produce **code** (a `diff` artifact) for
review + promotion.

## How it works (hybrid: platform agents + flow nodes)

- **Persona = platform agent.** Each `ai_coding` node declares
  `settings.agent: bmad-bmm:<stem>` (engine `1.5.0`). The agent's `.md` body
  becomes the node's system prompt; the node's task block is appended.
- **Process = vendored skill.** Node prompts drive the vendored `bmad-*` skills
  (materialized into the run worktree's `.claude/skills/`). The node preamble
  tells the agent to skip each skill's interactive "activation / greet / menu /
  wait for input" steps and execute the `<workflow>` body non-interactively.
- **Interactivity → HITL gates.** BMAD's per-document elicitation is replaced by
  MAIster `human` review gates (approve / rework / takeover). Agents make
  best-judgment decisions; corrections arrive through the gates.
- **Substrate.** Each flow opens with a `cli` `substrate` node that writes
  `_bmad/bmm/config.yaml` into the worktree idempotently (the canonical form is
  `capability/reference/_bmad-substrate/config.yaml.template`). There is **no
  `setup.sh`** — it would run in the package dir, not the project repo. There is
  no external CLI dependency, so no `requirements` probe.
- **MAIster owns git + promotion.** Agents commit locally only; MAIster handles
  branch/merge/PR.

## Deviations from the upstream BMAD runtime

- The interactive agent activation (greeting + capability menu + per-step
  `<ask>` prompts) is **not** reproduced — MAIster runs agents headless. The
  persona is carried by the platform agent; choices become gate decisions.
- The `_bmad/` substrate is the **minimal** subset the skills read
  (`config.yaml`), provisioned by the flow's `substrate` node — not the full
  `npx bmad-method install` tree. The `resolve_customization.py` resolver is
  omitted (the skills fall back to reading the vendored `customize.toml`).
- BMAD's `sprint-status.yaml` story board stays an in-worktree artifact; it is
  **not** wired to the MAIster task board (a Phase-2 enhancement).
- `bmm-dev-story` runs the **project's own** test command inside the
  `bmad-dev-story` skill (the test command is project-specific); MAIster does
  not hardcode a `command_check` test gate. Quality is enforced by the skill's
  definition-of-done checklist + an `ai_judgment` gate + human review.

## Install (local dev)

```bash
# from the MAIster web tier
pnpm install-package --source /abs/path/to/maister-plugins/packages/bmad-bmm \
  --version local-dev --project <slug>
```

After install, the six agents register in the platform agent catalog and the
three `bmm-*` flows are available on the project board.
