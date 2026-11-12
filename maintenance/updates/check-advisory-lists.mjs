#!/usr/bin/env bun
// Open an issue for each advisory in a dependency's own advisory list that covers its pinned version.
//
//   GH_TOKEN=… bun maintenance/updates/check-advisory-lists.mjs <report.json>
//
// <report.json> is the file Renovate writes with `reportType: file`; it gives each pinned version. The lists read are in maintenance/updates/advisory-lists.json, and why they are read is in maintenance/updates/README.md, "Advisory lists read weekly".

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fail, isRequirement, readPackageFiles } from "./renovate-report.mjs";

const gh = (...args) => execFileSync("gh", args, { encoding: "utf8" });
const packageFiles = readPackageFiles(process.argv[2]);

/** @returns {{ version: string, packageFile: string }[]} each version of the dependency in use */
const pinsOf = (depName) =>
  Object.values(packageFiles)
    .flat()
    .filter((f) => !isRequirement(f.packageFile))
    .flatMap((f) =>
      f.deps
        .filter((d) => d.depName === depName && d.currentValue)
        .map((d) => ({ version: d.currentValue.replace(/^v/, ""), packageFile: f.packageFile })),
    );

const readers = {
  // A repository's own advisories, the list GitHub shows on its Security tab.
  github: (depName) =>
    JSON.parse(gh("api", "--paginate", "--slurp", `repos/${depName}/security-advisories`)).flat(),
};

const lists = JSON.parse(readFileSync("maintenance/updates/advisory-lists.json", "utf8"));
for (const { depName, source } of lists) {
  const read = readers[source];
  if (!read)
    fail(
      `maintenance/updates/advisory-lists.json names source "${source}" for ${depName}, which this script cannot read.`,
    );
  const pins = pinsOf(depName);
  if (!pins.length)
    fail(
      `The Renovate report holds no version of ${depName}, so its advisories cannot be compared with one.`,
    );
  for (const advisory of read(depName))
    for (const { version, packageFile } of pins) {
      // GitHub writes a range as `>= 2.2.0, <= 2.9.5`; Bun.semver reads the same range without the comma.
      const affected = (advisory.vulnerabilities ?? []).some(
        (vulnerability) =>
          vulnerability.vulnerable_version_range &&
          Bun.semver.satisfies(version, vulnerability.vulnerable_version_range.replaceAll(",", "")),
      );
      if (!affected) continue;
      // An issue in any state counts: a closed one is the owner's decision on this advisory.
      const existing = gh(
        "issue",
        "list",
        "--state",
        "all",
        "--search",
        `"${advisory.ghsa_id}" in:title`,
        "--json",
        "number",
      );
      if (JSON.parse(existing).length) break;
      const fixedIn = (advisory.vulnerabilities ?? [])
        .map((vulnerability) => vulnerability.patched_versions)
        .filter(Boolean)
        .join(", ");
      const body = [
        advisory.html_url,
        "",
        `- Severity: ${advisory.severity}`,
        `- Fixed in: ${fixedIn || "no release yet"}`,
        `- Pinned: ${version} in \`${packageFile}\``,
        "",
        advisory.summary,
      ].join("\n");
      const priority = advisory.severity === "critical" ? "p0" : "p1";
      const title = `${depName} ${version} has advisory ${advisory.ghsa_id}`;
      console.log(
        gh(
          "issue",
          "create",
          "--title",
          title,
          "--label",
          "bug",
          "--label",
          priority,
          "--body",
          body,
        ).trim(),
      );
      break;
    }
}
