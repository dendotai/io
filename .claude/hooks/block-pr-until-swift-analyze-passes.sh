#!/bin/bash
# Claude Code `PreToolUse` hook (.claude/settings.json): blocks a `gh pr create` whose branch changes a Swift file until maintenance/code-style/analyze-swift.sh passes. It runs only for Claude, because a git hook would stop every commit or push for the minute the clean build takes; CI's `build` job enforces the same check for every PR.
set -euo pipefail

input=$(cat)
command=$(jq -r '.tool_input.command // ""' <<<"$input")
# Also matches `gh -R <repo> pr create`; a match in other text (an `echo`) only costs one run.
if ! grep -qE '(^|[^[:alnum:]_-])gh( .*)? pr +create' <<<"$command"; then
    exit 0
fi

cwd=$(jq -r '.cwd // ""' <<<"$input")
root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
# A branch cut before the script existed has nothing to run.
if [ ! -x "$root/maintenance/code-style/analyze-swift.sh" ]; then
    exit 0
fi
if ! changed=$(git -C "$root" diff --name-only origin/dev...HEAD -- '*.swift' 2>&1); then
    echo "git diff origin/dev...HEAD failed, so the Swift check cannot tell what the branch changes (run \`git fetch origin dev\`): $changed" >&2
    exit 2
fi
if [ -z "$changed" ]; then
    exit 0
fi

if ! report=$("$root/maintenance/code-style/analyze-swift.sh" 2>&1); then
    {
        echo "maintenance/code-style/analyze-swift.sh failed; fix each finding (or mark a false one with \`// swiftlint:disable:next <rule>\` and its reason), commit, and open the PR again:"
        echo "$report"
    } >&2
    exit 2
fi
