# Vendored pstack capability

This directory contains the pstack skills and reusable agent definitions from
`cursor/plugins`, pinned to commit
`7314f723a487ec406b6369fe5865ba034cfed166` (pstack `0.14.8`). The upstream
license is preserved in `LICENSE.pstack`.

The vendored material is kept close to upstream. The only source adaptations
are identifier normalization required by portable skill loaders:

- `Poteto Mode` became `poteto-mode`.
- `Make Bot UI` became `make-bot-ui`.
- `Comment Sicko` became `comment-sicko`, including its internal reference.

Some skills describe Cursor-native controls such as Task subagents,
`AskQuestion`, `/loop`, pstack model-selection rules, worktrees, or PR
operations. Those descriptions remain useful as source guidance, but they are
not the MAIster runtime contract. The package flows prepend an explicit
execution contract: MAIster owns orchestration, workspace lifecycle, review,
promotion, and human gates; capability agents stay inside the current node and
do not depend on Cursor-native controls.
