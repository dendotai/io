#!/usr/bin/env bun
// Open one PR that adds to maintenance/updates/renovate-pins.json each version pin Renovate found and the list lacks, or add the pins to that PR while it is open.
//
//   GH_TOKEN=… bun maintenance/updates/open-pins-pr.mjs <unlisted-pins.json>
//
// <unlisted-pins.json> is the file check-renovate.mjs writes. GH_TOKEN must be an app token, because a PR opened with GITHUB_TOKEN starts no workflow, so its checks never run. Why a pin the list lacks gets a PR and the other failures an issue is in maintenance/updates/README.md, "The check on each push".

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { PINS_LIST, pinPlace } from "./renovate-report.mjs";

const BRANCH_PREFIX = "renovate-pins/add-missing-";

export const pinsToAdd = (unlisted, list) => {
  const seen = new Set(list.map(pinPlace));
  return unlisted.filter((p) => {
    const key = pinPlace(p);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

export const prBody = (pins) =>
  [
    `Renovate's regex rules found these version pins, which \`${PINS_LIST}\` did not list:`,
    "",
    ...pins.map((p) => `- \`${p.depName}\` in \`${p.file}\``),
    "",
    "Merge this PR to accept them. When a rule in `renovate.json` matches a line it should not, fix the rule, then close this PR.",
  ].join("\n");

if (import.meta.main) {
  const gh = (args, input) => execFileSync("gh", args, { encoding: "utf8", input });
  const { GITHUB_REPOSITORY: repo, GITHUB_REF_NAME: base, GITHUB_SHA: sha } = process.env;

  // A second PR would append to the same array and conflict once the first merges, so new pins join the open PR.
  const pr = JSON.parse(
    gh([
      "pr",
      "list",
      "--repo",
      repo,
      "--state",
      "open",
      "--limit",
      "100",
      "--json",
      "number,url,headRefName,headRefOid",
    ]),
  ).find((p) => p.headRefName.startsWith(BRANCH_PREFIX));

  const baseList = JSON.parse(readFileSync(PINS_LIST, "utf8"));
  const prList = pr
    ? JSON.parse(
        Buffer.from(
          gh(["api", `repos/${repo}/contents/${PINS_LIST}?ref=${pr.headRefName}`, "--jq", ".content"]),
          "base64",
        ).toString("utf8"),
      )
    : baseList;
  const toAdd = pinsToAdd(JSON.parse(readFileSync(process.argv[2], "utf8")), prList);
  if (!toAdd.length) process.exit(0);

  const list = [...prList, ...toAdd];
  const branch = pr?.headRefName ?? `${BRANCH_PREFIX}${process.env.GITHUB_RUN_ID}-${process.env.GITHUB_RUN_ATTEMPT}`;
  const title = "chore: list the version pins Renovate found";
  const listed = new Set(baseList.map(pinPlace));
  const body = prBody(list.filter((p) => !listed.has(pinPlace(p))));

  if (!pr)
    gh(["api", "-X", "POST", `repos/${repo}/git/refs`, "-f", `ref=refs/heads/${branch}`, "-f", `sha=${sha}`]);
  // A commit made through the API is signed as the app, and `dev` requires signed commits; a `git push` from a workflow is unsigned.
  const commit = {
    query:
      "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }",
    variables: {
      input: {
        branch: { repositoryNameWithOwner: repo, branchName: branch },
        message: { headline: title },
        expectedHeadOid: pr?.headRefOid ?? sha,
        fileChanges: {
          additions: [
            {
              path: PINS_LIST,
              contents: Buffer.from(`${JSON.stringify(list, null, 2)}\n`).toString("base64"),
            },
          ],
        },
      },
    },
  };
  gh(["api", "graphql", "--input", "-"], JSON.stringify(commit));
  if (pr) {
    gh(["pr", "edit", String(pr.number), "--repo", repo, "--body", body]);
    console.log(pr.url);
  } else
    console.log(
      gh([
        "pr",
        "create",
        "--repo",
        repo,
        "--base",
        base,
        "--head",
        branch,
        "--title",
        title,
        "--body",
        body,
      ]).trim(),
    );
}
