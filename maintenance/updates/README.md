# Updates

Every version pin in this repo gets an update rule or a reason why it has none. A version pin is any place that picks a version of something from outside the repo: an exact version, a range, a major only (`@v6`), a label that names a version, `latest`, or copied content with no version string.

## How updates run

Renovate opens the update PRs. [`.github/workflows/renovate.yml`](../../.github/workflows/renovate.yml) runs it every Monday at 03:17 UTC, and **Run workflow** on the workflow's page in the Actions tab starts a run at any time. It runs as a GitHub App: a PR opened with `GITHUB_TOKEN` starts no workflow, so its checks would never run.

Each update PR runs every check in [`.github/workflows/test.yml`](../../.github/workflows/test.yml) on the new version, so a green PR shows the bump works for what those checks run. `test.yml` does not run `renovate.yml` or `maintenance.yml`: the next Renovate run is the proof for a pin in `renovate.yml`, and a pin in `maintenance.yml` has no check on an update PR. Nothing merges unattended. Renovate also keeps one issue, **Dependency Dashboard**, that lists every pending and skipped update.

A bump merged into `dev` ships with the next release, so an update PR needs no `fix:` prefix. Every minor and patch update arrives in one PR a week (`group:allNonMajor`), so a green PR is one merge. Each major update gets its own PR, because a major often needs a code change, and a red major in the weekly PR would hold every other update.

## Version pins with an update rule

| Version pin                                                         | Where                                                                                                    | Update rule                                                                                    |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Swift packages (Sparkle)                                            | `io.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `io.xcodeproj/project.pbxproj` | Two regex rules in `renovate.json`, for any package hosted on GitHub                           |
| Workflow actions (`uses:`)                                          | `test.yml`, `release.yml`, `renovate.yml`, `dependency-submission.yml`                                   | `helpers:pinGitHubActionDigests`: the full commit SHA and the `# vX.Y.Z` comment move together |
| `ubuntu-24.04` (`runs-on:`)                                         | `test.yml`, `maintenance.yml`, `renovate.yml`, `dependency-submission.yml`                               | Renovate's `github-actions` manager                                                            |
| `node-version`                                                      | `test.yml`, `release.yml`, `dependency-submission.yml`, `renovate.yml`                                   | Renovate's `github-actions` manager                                                            |
| `devDependencies`, `packageManager`                                 | `package.json`, `bun.lock`                                                                               | Renovate's `bun` manager, at exact versions (`:pinAllExceptPeerDependencies`)                  |
| CI tools (`renovate`, `semantic-release`, `@semantic-release/exec`) | `.github/package.json`, `.github/bun.lock`                                                               | Renovate's `bun` manager, at exact versions (`:pinAllExceptPeerDependencies`)                  |
| Release binaries (SwiftFormat, SwiftLint)                           | `tools.toml`                                                                                             | One regex rule in `renovate.json` with the `github-releases` datasource, for every entry       |

- **Swift packages (Sparkle):** Renovate's Swift manager reads only `Package.swift`, and an Xcode project stores its packages in `project.pbxproj` and `Package.resolved`. The `Package.resolved` rule edits `revision` and `version` together. The `project.pbxproj` rule edits `minimumVersion`, because a move to Sparkle 3 fails `upToNextMajorVersion` without that edit. Both rules take the package name from its GitHub URL, so both edits of one package land in one PR. `originHash` stays as it is, because SwiftPM hashes no version into it. Sparkle follows the same rules as every other pin. A green build is the proof, with no test release, so a broken Sparkle updater stays possible and costs a manual download.
- **CI tools:** every tool that runs only in a workflow is installed with `bun install --frozen-lockfile --cwd .github` and run from `.github/node_modules/.bin`, so the lockfile fixes every package it runs and the snapshot below sends them all to the dependency graph. `commitlint` stays in the root `package.json`, because the `commit-msg` hook runs it on every commit.
- **`semantic-release`:** the `semantic-release-dry-run` job in `test.yml` runs the new version with `--dry-run`, so a version that cannot load the release config fails its update PR, not the next release.

## Version pins with no update rule

- **`xcode-27` (`runs-on:` in `test.yml` and `release.yml`):** Renovate's `github-actions` manager accepts only `ubuntu`, `macos`, and `windows` labels and skips this one with no error, and the label has no list of versions a regex rule could read. It is the only GitHub-hosted label with the macOS 27 the package and the app require, and GitHub lists it as a preview ([runner images](https://github.com/actions/runner-images#available-images)). When GitHub lists a `macos-27` label, a PR changes these lines by hand.
- **Tools on the runners (`xcodebuild`, `codesign`, `security`, `notarytool`, `gh`, `jq`, `git`):** they come with the runner image, which `runs-on:` picks.
- **Swift and macOS versions (`swift-tools-version` in `Packages/Priority/Package.swift`, `SWIFT_VERSION` and `MACOSX_DEPLOYMENT_TARGET` in `io.xcodeproj/project.pbxproj`, `--swiftversion` in `.swiftformat`, which matches `SWIFT_VERSION`, `.macOS("27.0")` in `Packages/Priority/Package.swift`):** each is a decision about the code, not a dependency. A new Swift language mode can need code changes, and a higher macOS target drops users, so no bump comes on its own.
- **File format versions (`objectVersion`, `preferredProjectObjectVersion`, `LastSwiftUpdateCheck`, and `LastUpgradeCheck` in `io.xcodeproj/project.pbxproj`, `version` in `Package.resolved`, `lockfileVersion` in `bun.lock` and `.github/bun.lock`):** the tools that own these files write them.
- **`@semantic-release/*` plugins other than `exec`:** they come with `semantic-release`.
- **`$schema` in `renovate.json`:** an editor hint, always the newest on purpose.
- **`latest` in the appcast and download URLs (`io-Info.plist`, `README.md`, `RELEASING.md`):** they point at this repo's own releases, not at something from outside the repo.
- **Files copied from the owner's project template (`renovate.json`, `.github/workflows/renovate.yml`, `maintenance/updates/`):** copied content with no version string. The template is private, so no rule in this public repo can read it.
- **`docs/agents/` and the "Agent skills" section of `CLAUDE.md`:** settings for skills installed outside the repo.
- **Values copied from the Sound menu (`docs/sound-menu.md`):** copied content that follows macOS, measured by hand with the macOS version beside them (ADR 0002). The next measure replaces them.

## Security advisories

A security advisory for a pinned version reaches the owner as an update PR or an issue, never only as a notification or an email, because those have no owner and no reminder.

- **GitHub's Dependabot alerts:** GitHub's own parser reads `package.json`, `Package.resolved`, and workflows, not `bun.lock`, and raises no alert for an action pinned to a commit SHA. So on each push to `dev`, [`.github/workflows/dependency-submission.yml`](../../.github/workflows/dependency-submission.yml) sends every pin in Renovate's report, plus every package in `bun.lock` and `.github/bun.lock`, to the dependency graph as a snapshot (`maintenance/updates/build-dependency-snapshot.mjs`). An action goes in at the version in its `# vX.Y.Z` comment. A new snapshot replaces the last one, so a removed or bumped pin closes its alert. A pin kind the script has no package URL for fails the job, so no pin drops out unseen.
- **Until a tool turns an alert into an issue,** the weekly Renovate run is the signal: Renovate reads the repo's alerts and opens a `[SECURITY]` update PR.
- **A dependency's own advisory list:** GitHub raises an alert only for an advisory it has reviewed, so the scheduled `dependency-submission` run reads the lists in "Advisory lists read weekly", up to 7 days after an advisory is published.

## Version pins with no advisory source

These pins are left out of the snapshot, because GitHub keeps no advisories for them:

- **Runner images (`ubuntu-24.04`, `xcode-27`) and the tools on them, Xcode included:** no advisory database lists a runner image.
- **`node-version`:** Node's own advisories are in no GitHub ecosystem.
- **Sparkle's `minimumVersion` in `project.pbxproj`:** a requirement, not the version in use; `Package.resolved` holds that one.

## Advisory lists read weekly

Each Monday, and on a run started with **Run workflow**, `dependency-submission` reads each list in `maintenance/updates/advisory-lists.json` (`maintenance/updates/check-advisory-lists.mjs`), takes each pinned version from Renovate's report, and opens one issue per advisory whose version range covers the pinned version. It opens no second issue for an advisory that has one in any state, so a closed issue is the decision on that advisory.

- **Sparkle:** read from `repos/sparkle-project/Sparkle/security-advisories` and compared with the version in `Package.resolved`. Some of Sparkle's advisories are in neither GitHub's reviewed database nor OSV. The script compares ranges and ignores the package name, because Sparkle's advisories name the package in three ways (`github.com/sparkle-project/Sparkle`, `sparkle-project/Sparkle`, `Sparkle`).

## One-time GitHub App setup

There is one app per repository visibility for an owner (a user or an organization). This public repo runs as the owner's public app.

- Create the app: GitHub → Settings → Developer settings → GitHub Apps → **New GitHub App**. Turn off the webhook, and give it these repository permissions:
  - Read and write: Checks, Commit statuses, Contents, Issues, Pull requests, Workflows.
  - Read: Administration, Dependabot alerts, Metadata.
- Generate a private key on the app's page.
- Install the app on each repository of that visibility that runs Renovate.
- Keep the app's **Client ID** and the private key in a secret store, then set them on the repository, not on an environment, because the Renovate job runs outside `prod`. For example, with the 1Password CLI:

```bash
gh variable set RENOVATE_CLIENT_ID --body "$(op read "op://<vault>/<item>/renovate/client-id")"
op read "op://<vault>/<item>/renovate/private-key" | gh secret set RENOVATE_PRIVATE_KEY
```

## Declining an update

Renovate keeps no record of the updates it proposed: each run proposes the newest version of every package that is behind.

- **One update in the weekly PR breaks a check:** revert that package in the PR's branch and merge the rest. The next run proposes it again, so a fixed release arrives on its own. Until one ships, add a rule to `renovate.json` that skips the broken version (`"matchPackageNames": ["<name>"], "allowedVersions": "!/^1\\.2\\.3$/"`) so the weekly PR stays green, and delete the rule once a newer release passes.
- **Closing the weekly PR declines nothing:** the next run opens it again with the same title.
- **Closing a major-update PR** skips the exact version its title names (`to 5.0.0`, not `to v5`), so the next release of that major opens a new PR, which is the retest.

## A new version pin

A change that adds a kind Renovate does not find on its own adds a rule to `renovate.json` in the same commit, or adds its reason here. The rule for a line a `customManagers` rule reads is in the "Version pins" section of `CLAUDE.md`.

## The check on each push

Renovate skips a line its regex rule cannot match, and a file its ignore presets cover (`config:recommended` ignores `**/test/**`, `**/tests/**`, `**/__tests__/**`, `**/__fixtures__/**`, `**/examples/**`, `**/vendor/**` and `**/node_modules/**`), and reports no error. So on each push to `dev`, [`.github/workflows/dependency-submission.yml`](../../.github/workflows/dependency-submission.yml) runs Renovate in extract-only mode on the checkout, and `maintenance/updates/check-renovate.mjs` compares its report with the repo:

- Every regex finding against the places in `maintenance/updates/renovate-pins.json`, both ways.
- Every tracked `package.json` with dependencies, and every workflow with a `uses:` line or a versioned `runs-on:`, against the files the `bun` and `github-actions` managers found.

A pin Renovate found that the list lacks opens one PR that adds a line for each such pin (`maintenance/updates/open-pins-pr.mjs`), so the PR needs no edit before it merges; a pin an open PR already adds is skipped. When a rule in `renovate.json` matches a line it should not, fix the rule, then close the PR.

A listed pin Renovate no longer finds, or a file a manager skipped, opens one issue, **Renovate missed an expected version pin**, labelled `needs-human`, or comments on it when it is already open, because the fix needs to know whether the change was meant. Fix the rule or the list, then close the issue.
