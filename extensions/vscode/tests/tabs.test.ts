import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  commandsFor, findClaudeTabs, isClaudeViewType, judge,
  type ClaudeTab, type GroupLike,
} from "../src/tabs.js";

const claude = (label: string, active = false) => ({ label, isActive: active, viewType: "mainThreadWebview-claudeVSCodePanel" });
const other = (label: string) => ({ label, isActive: false, viewType: undefined });

describe("finding Claude Code tabs", () => {
  const groups: GroupLike[] = [
    { viewColumn: 1, tabs: [other("index.ts"), claude("Release plan", true), claude("Release plan")] },
    { viewColumn: 2, tabs: [claude("Notes"), { label: "Preview", isActive: false, viewType: "mainThreadWebview-markdown.preview" }] },
  ];

  it("returns only Claude panels, with group and position", () => {
    assert.deepEqual(findClaudeTabs(groups).map((t) => [t.viewColumn, t.index, t.label]), [
      [1, 1, "Release plan"], [1, 2, "Release plan"], [2, 0, "Notes"],
    ]);
  });

  it("recognises the type with or without the VS Code prefix, and nothing else", () => {
    assert.equal(isClaudeViewType("claudeVSCodePanel"), true);
    assert.equal(isClaudeViewType("mainThreadWebview-claudeVSCodePanel"), true);
    for (const type of [undefined, "", "claudePlanPreview", "mainThreadWebview-claudeVSCodePanelX", "xclaudeVSCodePanel"]) {
      assert.equal(isClaudeViewType(type), false, String(type));
    }
  });
});

describe("reaching a tab by position", () => {
  const tab = (viewColumn: number, index: number): ClaudeTab => ({ viewColumn, index, label: "t", isActive: false });

  it("builds the built-in command names for reachable positions", () => {
    assert.deepEqual(commandsFor(tab(1, 0)), { focusGroup: "workbench.action.focusFirstEditorGroup", openAtIndex: "workbench.action.openEditorAtIndex1" });
    assert.deepEqual(commandsFor(tab(8, 8)), { focusGroup: "workbench.action.focusEighthEditorGroup", openAtIndex: "workbench.action.openEditorAtIndex9" });
  });

  it("says unreachable instead of guessing beyond the built-in range", () => {
    assert.equal(commandsFor(tab(9, 0)), null);
    assert.equal(commandsFor(tab(1, 9)), null);
    assert.equal(commandsFor(tab(0, 0)), null);
  });
});

describe("judging an attempt", () => {
  const target: ClaudeTab = { viewColumn: 1, index: 2, label: "t", isActive: false };

  it("trusts only what the tab API reports afterwards", () => {
    assert.equal(judge(target, false, { ...target, isActive: true }, true), "worked");
    assert.equal(judge(target, false, { ...target, index: 1 }, true), "wrongTab");
    assert.equal(judge(target, false, { ...target, viewColumn: 2 }, true), "wrongTab");
    assert.equal(judge(target, false, undefined, true), "didNotChange");
  });

  it("refuses to call an already-active tab a success, and flags unreachable ones", () => {
    assert.equal(judge(target, true, target, true), "alreadyActive");
    assert.equal(judge(target, false, target, false), "unreachable");
  });
});
