# MAIster Core package

First-party platform agents and shared skills that ship with MAIster.

## Contents

- `maister-agents/` — platform-agent definitions catalogued as
  `core:<file-stem>`.
- `capability/skills/` — shared skills materialized into supported agent
  runtimes from the installed package revision.
- `evaluation-methods/sdd-quality/` — the default MAIster Evaluation Lab method
  (M46, ADR-143): an operationalized spec-driven-development rubric with a
  strict judge result schema. Requires MAIster engine `>= 3.2.0`; older control
  planes ignore the `evaluationMethods` key. Content is inert until trusted and
  engine-compatible.
- No flows or MCP server templates. Core agents use MAIster's built-in MCP
  facade and ephemeral agent tokens.

## Adding a skill

Create `capability/skills/<skill-id>/SKILL.md`. References, scripts, examples,
and templates may live beside `SKILL.md` inside the same skill directory.
Individual skills are discovered from the registered `core-bundle` capability;
they are not listed separately in `maister-package.yaml`.

## Versioning

Release with a `core/vX.Y.Z` tag. Existing MAIster installations must upgrade
to that package revision before the new content is available to runs.
