# Releasing

A release is a `dev` → `main` pull request. Its merge builds, signs, and notarizes the app, then publishes it on GitHub Releases, where the app finds it.

## The flow

- Feature pull requests merge into `dev`. The `commitlint` job in `.github/workflows/test.yml` checks that each of their commits has a conventional prefix (`feat:`, `fix:`, `chore:`, …).
- To release, open a pull request from `dev` into `main` titled `Release TBD`, with a `## What's Changed` list of the commits it brings.
- Merge it with a **merge commit**. A squash merge turns the pull request title into the one commit semantic-release reads, and `Release TBD` carries no prefix.
- The push to `main` runs `.github/workflows/release.yml`. Its `Release` step runs semantic-release, which reads the commits since the last tag and picks the version.
- semantic-release's prepare step runs `scripts/build-release.sh`, which writes `dist/io.zip` and `dist/appcast.xml`. A failure there stops the run before the tag, so nothing is published.
- `scripts/build-release.sh` builds the app with `scripts/build-app.sh`, the script the `build` job in `.github/workflows/test.yml` runs on every pull request.
- semantic-release then pushes the tag (`v0.1.0`) and writes the GitHub release with its notes and both files.
- The `Rename the merged release PR` step renames the merged pull request to `Release v0.1.0`.

`package.json` stays at `0.0.0`: the release version lives in git tags and GitHub releases, so no release commit lands on `main`.

## Which prefix raises which part

| Commits since the last tag                      | Release             |
| ----------------------------------------------- | ------------------- |
| a `fix:`                                        | `v0.1.0` → `v0.1.1` |
| a `feat:`                                       | `v0.1.1` → `v0.2.0` |
| `BREAKING CHANGE:` in the body                  | `v0.2.0` → `v1.0.0` |
| only `chore:`, `docs:`, `test:`, `perf:`, …     | no release          |

A `!` after the type raises nothing, because semantic-release's default preset does not read it.

The tag `v0.0.0` on the commit before the first release makes that release `v0.1.0`, because semantic-release starts at `1.0.0` in a repo with no tag.

## A failed upload

A failed upload leaves a pushed tag and a draft release, and a rerun finds no new commits. Delete the draft and the tag, then rerun the workflow.

## How an update reaches the app

- The app reads `https://github.com/dendotai/io/releases/latest/download/appcast.xml` about once a day. That file lists the newest release only, as a full update.
- The script sets `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` to the release version, because Sparkle compares the feed's version with `CFBundleVersion`.
- The script builds with `PUBLISHED_RELEASE`, the only condition that starts the updater, so a local build never replaces itself with a release.

## Secrets

The `prod` GitHub environment holds them, and only `main` can read it.

| Secret                                 | Holds                                         |
| -------------------------------------- | --------------------------------------------- |
| `DEVELOPER_ID_APPLICATION_CERTIFICATE` | base64 of the Developer ID `.p12` file        |
| `DEVELOPER_ID_APPLICATION_PASSWORD`    | the password of that file                     |
| `ASC_KEY`                              | text of the App Store Connect API `.p8` file  |
| `ASC_KEY_ID`                           | the ID of that key                            |
| `ASC_ISSUER_ID`                        | the issuer ID of that key                     |
| `SPARKLE_EDDSA_PRIVATE_KEY`            | the private key that signs updates            |

The public half of the EdDSA key is `SUPublicEDKey` in `io-Info.plist`. A new key pair locks out every installed app, because an installed app accepts only updates signed with the key it shipped with.

## A local run

`scripts/build-release.sh <version>` runs on a Mac with the secrets above in its environment and writes `dist/`. Set `SOURCE_PACKAGES_DIR` to the absolute path of a folder that holds already fetched packages, because a fetch into an empty folder can open a login keychain dialog.
