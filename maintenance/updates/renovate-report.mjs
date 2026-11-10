// Read Renovate's report, the file it writes with `reportType: file` (https://docs.renovatebot.com/self-hosted-configuration/#reporttype), and the pin list, for the scripts in this folder.

import { readFileSync } from "node:fs";

export const PINS_LIST = "maintenance/updates/renovate-pins.json";

export const pinPlace = ({ file, depName }) => `${depName} in ${file}`;

export const fail = (message) => {
  console.error(message);
  process.exit(1);
};

/** @returns {Record<string, { packageFile: string, deps: { depName: string, packageName?: string, datasource?: string, depType?: string, currentValue?: string }[] }[]>} the package files Renovate found, by manager */
export const readPackageFiles = (reportPath) => {
  let report;
  try {
    report = JSON.parse(readFileSync(reportPath, "utf8"));
  } catch (err) {
    fail(`Cannot read the Renovate report at ${reportPath}: ${err.message}`);
  }
  // `reportType` is experimental, so its shape can change in any Renovate release.
  const packageFiles = Object.values(report.repositories ?? {})[0]?.packageFiles;
  if (!packageFiles)
    fail(`The Renovate report at ${reportPath} has no packageFiles; its shape changed.`);
  return packageFiles;
};

// An Xcode project's `minimumVersion` is a requirement; the version in use is in Package.resolved.
export const isRequirement = (packageFile) => packageFile.endsWith("project.pbxproj");
