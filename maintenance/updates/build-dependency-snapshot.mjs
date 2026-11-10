#!/usr/bin/env bun
// Print a dependency snapshot of every version pin, for GitHub's dependency submission API (https://docs.github.com/en/rest/dependency-graph/dependency-submission).
//
//   bun maintenance/updates/build-dependency-snapshot.mjs <report.json>
//
// <report.json> is the file Renovate writes with `reportType: file`; each bun.lock beside a package.json in it adds its transitive packages. The workflow's GITHUB_* variables fill the commit, the ref, and the job. Why GitHub's own parsing is not enough is in maintenance/updates/README.md, "Security advisories".

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fail, isRequirement, readPackageFiles } from "./renovate-report.mjs";

// GitHub writes a scoped npm name with `%40` in its own package URLs.
const npmUrl = (name, version) => `pkg:npm/${name.replace(/^@/, "%40")}@${version}`;

// A pin GitHub keeps no advisories for gets no package URL; its reason is in maintenance/updates/README.md, "Version pins with no advisory source".
const leftOut = ({ manager, packageFile, dep }) =>
  dep.depType === "github-runner" ||
  dep.datasource === "docker" ||
  (dep.datasource === "github-releases" && dep.packageName === "actions/node-versions") ||
  (manager === "regex" && isRequirement(packageFile));

/** @returns {{ url: string, scope: "runtime" | "development" } | undefined} */
const packageOf = ({ manager, packageFile, dep }) => {
  if (dep.datasource === "npm")
    return { url: npmUrl(dep.packageName, dep.currentValue), scope: "development" };
  if (dep.datasource === "github-tags" && dep.depType === "action")
    return {
      url: `pkg:githubactions/${dep.packageName}@${dep.currentValue.replace(/^v/, "")}`,
      scope: "development",
    };
  if (
    dep.datasource === "github-tags" &&
    manager === "regex" &&
    packageFile.endsWith("Package.resolved")
  )
    // A Swift package ships inside the app, so it is a runtime package.
    return { url: `pkg:swift/github.com/${dep.packageName}@${dep.currentValue}`, scope: "runtime" };
  if (dep.datasource === "github-releases" && manager === "regex" && packageFile === "tools.toml")
    // Each tool in tools.toml is a Swift package on GitHub that runs only on a developer Mac and in CI.
    return {
      url: `pkg:swift/github.com/${dep.packageName}@${dep.currentValue}`,
      scope: "development",
    };
};

/** @returns {string[]} the package URLs of every registry package in the lockfile */
const lockedPackages = (lockText) =>
  Object.values(Bun.JSONC.parse(lockText).packages ?? {}).flatMap(([id]) => {
    const at = id.lastIndexOf("@");
    const name = id.slice(0, at);
    const version = id.slice(at + 1);
    if (version.startsWith("workspace:")) return [];
    if (!/^\d/.test(version))
      fail(
        `bun.lock holds ${id}, which is not a registry version; build-dependency-snapshot.mjs has no package URL for it.`,
      );
    return [npmUrl(name, version)];
  });

const buildManifests = (packageFiles, readLock) => {
  const manifests = {};
  const unknown = [];
  for (const [manager, files] of Object.entries(packageFiles))
    for (const { packageFile, deps } of files) {
      const resolved = manifests[packageFile]?.resolved ?? {};
      for (const dep of deps) {
        const pin = { manager, packageFile, dep };
        if (leftOut(pin)) continue;
        const pkg = dep.currentValue ? packageOf(pin) : undefined;
        if (!pkg) {
          unknown.push(
            `${dep.depName} (${dep.datasource}, ${dep.currentValue ?? "no version"}) in ${packageFile}`,
          );
          continue;
        }
        resolved[pkg.url] = { package_url: pkg.url, relationship: "direct", scope: pkg.scope };
      }
      const lockText =
        manager === "bun" ? readLock(join(dirname(packageFile), "bun.lock")) : undefined;
      for (const url of lockText ? lockedPackages(lockText) : [])
        resolved[url] ??= { package_url: url, relationship: "indirect", scope: "development" };
      if (Object.keys(resolved).length)
        manifests[packageFile] = {
          name: packageFile,
          file: { source_location: packageFile },
          resolved,
        };
    }
  if (unknown.length)
    fail(
      `build-dependency-snapshot.mjs has no package URL for these pins, so GitHub would raise no alert for them; add a rule or a reason to leave them out:\n${unknown.join("\n")}`,
    );
  return manifests;
};

if (import.meta.main) {
  const env = process.env;
  const snapshot = {
    version: 0,
    sha: env.GITHUB_SHA,
    ref: env.GITHUB_REF,
    // GitHub replaces the last snapshot with the same correlator, so a pin removed from the repo drops out of the graph.
    job: { correlator: `${env.GITHUB_WORKFLOW} ${env.GITHUB_JOB}`, id: env.GITHUB_RUN_ID },
    detector: {
      name: "maintenance/updates/build-dependency-snapshot.mjs",
      version: "1",
      url: `${env.GITHUB_SERVER_URL}/${env.GITHUB_REPOSITORY}/blob/${env.GITHUB_SHA}/maintenance/updates/build-dependency-snapshot.mjs`,
    },
    scanned: new Date().toISOString(),
    manifests: buildManifests(readPackageFiles(process.argv[2]), (path) =>
      existsSync(path) ? readFileSync(path, "utf8") : undefined,
    ),
  };
  console.log(JSON.stringify(snapshot, null, 2));
}
