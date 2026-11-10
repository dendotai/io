import { describe, expect, test } from "bun:test";
import { pinsToAdd } from "./open-pins-pr.mjs";

const widget = { file: "deps/Package.resolved", depName: "acme/widget" };
const gadget = { file: "deps/project.pbxproj", depName: "acme/gadget" };

describe("pinsToAdd", () => {
  test("adds every unlisted pin when no PR is open", () => {
    expect(pinsToAdd([widget, gadget], [])).toEqual([widget, gadget]);
  });

  test("skips a pin an open PR already adds", () => {
    expect(pinsToAdd([widget, gadget], [[widget]])).toEqual([gadget]);
  });

  test("adds nothing when open PRs cover every pin", () => {
    expect(pinsToAdd([widget], [[], [widget]])).toEqual([]);
  });

  test("adds a pin the report names twice only once", () => {
    expect(pinsToAdd([widget, widget], [])).toEqual([widget]);
  });
});
