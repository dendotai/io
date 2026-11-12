# Tools

`install-tools.sh` downloads each command-line tool listed in `tools.toml` at the repo root and links its executable into `.tools/bin/`, which git ignores. Nothing is built from source: each tool comes as the release file its author publishes on GitHub.

Each table in `tools.toml` is one tool:

- the table name is the name of the executable at the top level of the release file;
- `repo` is the GitHub repo, `version` the release tag, and `file` the zip in that release.

A new tool of the same kind is one more table, with no new install code. Renovate reads `repo` and `version` from every table, with `version` on the line after `repo`, and opens a PR when a tool has a new release (`maintenance/updates/README.md`). `maintenance/updates/build-dependency-snapshot.mjs` sends each table to the dependency graph as a Swift package, so a tool written in another language needs its own package URL there.

The script downloads only a version that is not in `.tools/` yet, so a second run makes no network call. The commands in `maintenance/code-style/` run it when their tool is missing or `tools.toml` changed since the last install; CI runs it as its own step and caches `.tools/` by the hash of `tools.toml`.
