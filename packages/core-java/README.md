# MAIster Core Java package

First-party Java engineering skills for MAIster agent sessions. The package is
a skill-only scaffold: it ships no flows, platform agents, or MCP templates.

## Intended scope

- JVM build systems and dependency management.
- Java application architecture and maintainability.
- Integration and end-to-end testing.
- Performance analysis and production diagnostics.

## Adding a skill

Create `capability/skills/<skill-id>/SKILL.md` and keep any supporting
references, scripts, examples, or templates inside that skill directory. The
`core-java-bundle` capability registers the entire `capability/` root, so no
per-skill manifest entry is required.

## Versioning

Release with a `core-java/vX.Y.Z` tag and upgrade the installed package revision
in MAIster.
