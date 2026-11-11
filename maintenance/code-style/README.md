# Code style

SwiftFormat keeps the Swift code in one style, and SwiftLint reports likely bugs. Both run over `io/`, `Packages/` and `scripts/`, at the versions in `tools.toml` (`maintenance/tools/README.md`).

| Command                     | Script                    | CI job (`test.yml`) |
| --------------------------- | ------------------------- | ------------------- |
| `bun run format`            | `format-swift.sh`         |                     |
| `bun run format -- --check` | `format-swift.sh --check` | `format-swift`      |
| `bun run lint`              | `lint-swift.sh`           | `lint-swift`        |
|                             | `analyze-swift.sh`        | `build`             |

The scripts use no bun, so CI runs them on the `xcode-27` runner with no bun setup step, and a flag in a script reaches the Mac and CI alike.

## SwiftFormat (`.swiftformat`)

- The default rules, with no opt-in rule.
- `--indent 4`: the indent the code had before the formatter.
- `--maxwidth 120`: SwiftFormat wraps a code line wider than SwiftLint's `line_length` warning, so the two tools never disagree on a line.
- `--disable wrapSingleLineComments`: each comment paragraph stays on one line, as `CLAUDE.md` asks.
- `--swiftversion 6.0`: the app's `SWIFT_VERSION`.

## SwiftLint (`.swiftlint.yml`)

- The default rules, every opt-in rule of kind `lint`, `force_unwrapping` and `closure_body_length`.
- `required_deinit` stays off: it asks for an empty `deinit` in each class and finds no bug.
- The analyzer rules (`capture_variable`, `typesafe_array_init`, `unused_declaration`, `unused_import`) run only under `swiftlint analyze`, over a full build log. `analyze-swift.sh` runs them with `--strict` after a Debug `clean build` (about 1 minute), or on a log it is given. They stay out of `bun run lint` for that minute. A Claude Code hook (`.claude/hooks/block-pr-until-swift-analyze-passes.sh`) runs the script before Claude opens a PR whose branch changes a Swift file, and the `build` job runs it on its Release build log.
- The style opt-in rules and the other idiomatic opt-in rules stay off: they repeat or contradict SwiftFormat and fix no bug.
- `opening_brace` is off and `trailing_comma` takes `mandatory_comma: true`, so SwiftFormat owns braces and commas.
- `line_length` ignores comments, because a comment paragraph is one line.
- `identifier_name` allows `x`, `y`, `i` and `id`.
- `lint-swift.sh` runs SwiftLint with `--strict`, so a warning fails it.
- A finding that is safe where it stands, as a force unwrap that cannot fail, carries `// swiftlint:disable:next <rule>` with its reason.
