# Domain Docs

How the engineering skills consume this repo's domain documentation.

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root.
- **`docs/adr/`**: read the ADRs that touch the area you're about to work in.

If a file doesn't exist, proceed silently. The `/domain-modeling` skill creates them when terms or decisions get resolved.

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a test name, a type), use the term as `GLOSSARY.md` defines it, not a synonym it lists under _Avoid_.

## Flag ADR conflicts

If your output contradicts an ADR, say so explicitly instead of overriding it silently.
