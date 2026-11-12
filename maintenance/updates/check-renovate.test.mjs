import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const pins = [{ file: "deps/Package.resolved", depName: "acme/widget" }];

const files = {
  "package.json": JSON.stringify({ devDependencies: { typescript: "5.9.3" } }),
  "deps/Package.resolved": "{}",
  ".github/workflows/test.yml": "jobs:\n  test:\n    runs-on: ubuntu-24.04\n",
};

const found = {
  bun: [{ packageFile: "package.json", deps: [] }],
  "github-actions": [{ packageFile: ".github/workflows/test.yml", deps: [] }],
  regex: [{ packageFile: "deps/Package.resolved", deps: [{ depName: "acme/widget" }] }],
};

// The report shape Renovate writes with `reportType: file`: per repository, the package files each manager found.
const report = (packageFiles) => ({
  repositories: { "acme/acme": { packageFiles } },
});

function check({ list = pins, packageFiles = found } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "check-renovate-test-"));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(join(dir, dirname(path)), { recursive: true });
    writeFileSync(join(dir, path), content);
  }
  mkdirSync(join(dir, "maintenance/updates"), { recursive: true });
  writeFileSync(join(dir, "maintenance/updates/renovate-pins.json"), JSON.stringify(list));
  for (const script of ["check-renovate.mjs", "renovate-report.mjs"])
    copyFileSync(join(import.meta.dir, script), join(dir, "maintenance/updates", script));
  spawnSync("git", ["init", "-q"], { cwd: dir });
  spawnSync("git", ["add", "."], { cwd: dir });
  writeFileSync(join(dir, "report.json"), JSON.stringify(report(packageFiles)));
  const run = spawnSync(
    "bun",
    ["maintenance/updates/check-renovate.mjs", "report.json", "unlisted-pins.json"],
    { cwd: dir, encoding: "utf8" },
  );
  const unlistedPath = join(dir, "unlisted-pins.json");
  const unlisted = existsSync(unlistedPath)
    ? JSON.parse(readFileSync(unlistedPath, "utf8"))
    : undefined;
  rmSync(dir, { recursive: true });
  return { status: run.status, output: run.stdout + run.stderr, unlisted };
}

describe("check-renovate", () => {
  test("passes silently and writes no unlisted pin when the list matches the report", () => {
    expect(check()).toEqual({ status: 0, output: "", unlisted: [] });
  });

  test("passes and writes each pin the list lacks, for the PR that adds it", () => {
    const extra = { packageFile: "deps/project.pbxproj", deps: [{ depName: "acme/widget" }] };
    const result = check({ packageFiles: { ...found, regex: [...found.regex, extra] } });
    expect(result).toEqual({
      status: 0,
      output: "",
      unlisted: [{ file: "deps/project.pbxproj", depName: "acme/widget" }],
    });
  });

  test("fails, naming the place, when Renovate did not find a listed pin", () => {
    const result = check({ packageFiles: { ...found, regex: [] } });
    expect(result.status).toBe(1);
    expect(result.output).toContain("Renovate did not find acme/widget in deps/Package.resolved");
    expect(result.unlisted).toEqual([]);
  });

  test("fails when a manager skipped a file", () => {
    const result = check({ packageFiles: { ...found, bun: [] } });
    expect(result.status).toBe(1);
    expect(result.output).toContain("Renovate's bun manager skipped package.json");
  });
});
