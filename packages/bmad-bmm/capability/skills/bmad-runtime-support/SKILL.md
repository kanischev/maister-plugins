---
name: bmad-runtime-support
description: Internal runtime support for the vendored BMAD Method skills. MAIster flows call its preparation script before invoking a BMAD workflow.
---

# BMAD runtime support

This is an internal package skill. Run `prepare.sh <project-slug>` from the
project root before invoking another vendored BMAD skill. It installs the
version-matched resolver and renderer scripts under `_bmad/scripts/` and creates
the package's default configuration only when the project has not supplied it.
