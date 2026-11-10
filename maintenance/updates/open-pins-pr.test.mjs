import { describe, expect, test } from "bun:test";
import { pinsToAdd, prBody } from "./open-pins-pr.mjs";

const widget = { file: "deps/Package.resolved", depName: "acme/widget" };
const gadget = { file: "deps/project.pbxproj", depName: "acme/gadget" };

describe("pinsToAdd", () => {
  test("adds every pin the list lacks", () => {
    expect(pinsToAdd([widget, gadget], [])).toEqual([widget, gadget]);
  });

  test("skips a pin the open PR's list already holds", () => {
    expect(pinsToAdd([widget, gadget], [widget])).toEqual([gadget]);
  });

  test("adds nothing when the list holds every pin", () => {
    expect(pinsToAdd([widget], [gadget, widget])).toEqual([]);
  });

  test("adds a pin the report names twice only once", () => {
    expect(pinsToAdd([widget, widget], [])).toEqual([widget]);
  });
});

describe("prBody", () => {
  test("lists each pin the PR adds", () => {
    expect(prBody([widget, gadget])).toContain(
      "- `acme/widget` in `deps/Package.resolved`\n- `acme/gadget` in `deps/project.pbxproj`",
    );
  });
});
