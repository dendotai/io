#!/usr/bin/env bun
// Open one PR that adds to maintenance/updates/renovate-pins.json each version pin Renovate found and the list lacks.
//
//   GH_TOKEN=… bun maintenance/updates/open-pins-pr.mjs <unlisted-pins.json>
//
// <unlisted-pins.json> is the file check-renovate.mjs writes. GH_TOKEN must be an app token, because a PR opened with GITHUB_TOKEN starts no workflow, so its checks never run. Why a missed pin gets a PR and the other failures an issue is in maintenance/updates/README.md, "The check on each push".

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const LIST = "maintenance/updates/renovate-pins.json";
const BRANCH_PREFIX = "renovate-pins/";

const place = ({ file, depName }) => `${depName} in ${file}`;

/** @returns the pins of `unlisted` that neither the list nor an open PR's copy of it holds */
export const pinsToAdd = (unlisted, listsInOpenPrs) => {
  const covered = new Set(listsInOpenPrs.flat().map(place));
  const seen = new Set();
  return unlisted.filter((p) => {
    const key = place(p);
    if (covered.has(key) || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

if (import.meta.main) {
  const gh = (args, input) => execFileSync("gh", args, { encoding: "utf8", input });
  const { GITHUB_REPOSITORY: repo, GITHUB_REF_NAME: base, GITHUB_SHA: sha } = process.env;

  const openBranches = JSON.parse(
    gh(["pr", "list", "--repo", repo, "--state", "open", "--limit", "100", "--json", "headRefName"]),
  )
    .map((pr) => pr.headRefName)
    .filter((ref) => ref.startsWith(BRANCH_PREFIX));
  const listsInOpenPrs = openBranches.map((ref) =>
    JSON.parse(
      Buffer.from(
        gh(["api", `repos/${repo}/contents/${LIST}?ref=${ref}`, "--jq", ".content"]),
        "base64",
      ).toString("utf8"),
    ),
  );

  const toAdd = pinsToAdd(JSON.parse(readFileSync(process.argv[2], "utf8")), listsInOpenPrs);
  if (!toAdd.length) process.exit(0);

  const list = [...JSON.parse(readFileSync(LIST, "utf8")), ...toAdd];
  const branch = `${BRANCH_PREFIX}${process.env.GITHUB_RUN_ID}-${process.env.GITHUB_RUN_ATTEMPT}`;
  const title = "chore: list the version pins Renovate found";
  const body = [
    `Renovate's regex rules found these version pins, which \`${LIST}\` did not list:`,
    "",
    ...toAdd.map((p) => `- \`${p.depName}\` in \`${p.file}\``),
    "",
    "Merge this PR to accept them; close it when a rule in `renovate.json` matches a line it should not.",
  ].join("\n");

  gh(["api", "-X", "POST", `repos/${repo}/git/refs`, "-f", `ref=refs/heads/${branch}`, "-f", `sha=${sha}`]);
  // A commit made through the API is signed as the app, and `dev` requires signed commits; a `git push` from a workflow is unsigned.
  const commit = {
    query:
      "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }",
    variables: {
      input: {
        branch: { repositoryNameWithOwner: repo, branchName: branch },
        message: { headline: title },
        expectedHeadOid: sha,
        fileChanges: {
          additions: [
            {
              path: LIST,
              contents: Buffer.from(`${JSON.stringify(list, null, 2)}\n`).toString("base64"),
            },
          ],
        },
      },
    },
  };
  gh(["api", "graphql", "--input", "-"], JSON.stringify(commit));
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
