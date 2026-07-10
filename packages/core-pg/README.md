# MAIster Core PostgreSQL package

First-party PostgreSQL engineering skills for MAIster agent sessions. The
package is a skill-only scaffold: it ships no flows, platform agents, or MCP
templates.

## Intended scope

- Schema design and safe migrations.
- Query planning, indexing, and performance tuning.
- Transactions, concurrency, and data integrity.
- Reliability, maintenance, observability, and production operations.

## Adding a skill

Create `capability/skills/<skill-id>/SKILL.md` and keep any supporting
references, scripts, examples, or templates inside that skill directory. The
`core-pg-bundle` capability registers the entire `capability/` root, so no
per-skill manifest entry is required.

## Versioning

Release with a `core-pg/vX.Y.Z` tag and upgrade the installed package revision
in MAIster.
