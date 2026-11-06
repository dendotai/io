## Conventions

Every commit message takes a conventional prefix (`feat:`, `fix:`, `chore:`, …).

Feature branches open PRs into `dev`; `dev` merges into `main` for a release.

Write each paragraph, list item, and comment point on one line.

A value copied from the Sound menu comes from `docs/sound-menu.md` (ADR 0002); a code constant that holds one names its element there.

## Version pins

A change that adds, moves, renames or reshapes a line a `customManagers` rule in `renovate.json` reads updates `renovate.json` and `maintenance/updates/renovate-pins.json` in the same commit, because Renovate skips a version pin it cannot find and reports no error. The weekly `renovate` workflow opens a `needs-human` issue when a run missed one. What counts as a version pin, and the ones with no update rule, are in `maintenance/updates/README.md`.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

See `docs/agents/triage-labels.md`.

### Domain docs

Single context: `GLOSSARY.md` at the root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.
