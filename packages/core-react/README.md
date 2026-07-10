# MAIster Core React package

First-party React and TypeScript frontend skills for MAIster agent sessions. The
package is a skill-only scaffold: it ships no flows, platform agents, or MCP
templates.

## Intended scope

- Component and hook design.
- State management and server/client data flow.
- Accessibility and interaction quality.
- Frontend testing, rendering performance, and bundle efficiency.

## Adding a skill

Create `capability/skills/<skill-id>/SKILL.md` and keep any supporting
references, scripts, examples, or templates inside that skill directory. The
`core-react-bundle` capability registers the entire `capability/` root, so no
per-skill manifest entry is required.

## Versioning

Release with a `core-react/vX.Y.Z` tag and upgrade the installed package
revision in MAIster.
