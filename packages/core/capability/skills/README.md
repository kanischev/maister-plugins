# Core skills

Add each reusable skill under its own directory:

```text
skills/
└── <skill-id>/
    ├── SKILL.md
    ├── references/   # optional
    ├── scripts/      # optional
    ├── examples/     # optional
    └── templates/    # optional
```

`SKILL.md` is required. MAIster discovers skill directories through the
`core-bundle` entry in the package manifest; this README is not materialized as
a skill.
