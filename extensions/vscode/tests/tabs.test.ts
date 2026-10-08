import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  PROVIDER_RULES, commandsFor, findConversationTabs, judge, providerForViewType,
  type EditorTab, type GroupLike,
} from "../src/tabs.js";

const claude = (label: string, active = false) => ({ label, isActive: active, viewType: "mainThreadWebview-claudeVSCodePanel" });
const codexPanel = (label: string) => ({ label, isActive: false, viewType: "mainThreadWebview-chatgpt.panelView" });
const codexEditor = (label: string) => ({ label, isActive: false, viewType: "chatgpt.conversationEditor" });
const other = (label: string) => ({ label, isActive: false, viewType: undefined });

describe("finding conversation tabs", () => {
  const groups: GroupLike[] = [
    { viewColumn: 1, tabs: [other("index.ts"), claude("Release plan", true), codexPanel("Release plan")] },
    { viewColumn: 2, tabs: [codexEditor("Refactor"), { label: "Preview", isActive: false, viewType: "mainThreadWebview-markdown.preview" }] },
  ];

  it("returns Claude Code and Codex conversations with their provider, group and position, and nothing else", () => {
    assert.deepEqual(findConversationTabs(groups).map((t) => [t.provider, t.viewColumn, t.index, t.label]), [
      ["claude-code", 1, 1, "Release plan"], ["codex", 1, 2, "Release plan"], ["codex", 2, 0, "Refactor"],
    ]);
  });

  it("recognises each type with or without the VS Code prefix, and nothing that merely resembles one", () => {
    assert.equal(providerForViewType("claudeVSCodePanel"), "claude-code");
    assert.equal(providerForViewType("mainThreadWebview-claudeVSCodePanel"), "claude-code");
    assert.equal(providerForViewType("chatgpt.panelView"), "codex");
    assert.equal(providerForViewType("mainThreadWebview-chatgpt.panelView"), "codex");
    assert.equal(providerForViewType("chatgpt.conversationEditor"), "codex");
    for (const type of [undefined, "", "claudePlanPreview", "claudeVSCodePanelX", "chatgpt.sidebarView", "chatgpt.sidebarSecondaryView", "chatgpt.panelViewX"]) {
      assert.equal(providerForViewType(type), undefined, String(type));
    }
  });

  it("gives every provider a distinct name and at least one view type", () => {
    assert.equal(new Set(PROVIDER_RULES.map((r) => r.provider)).size, PROVIDER_RULES.length);
    assert.ok(PROVIDER_RULES.every((r) => r.viewTypes.length > 0));
  });
});

describe("reaching a tab by position", () => {
  const tab = (viewColumn: number, index: number): EditorTab => ({ provider: "claude-code", viewColumn, index, label: "t", isActive: false });

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
  const target: EditorTab = { provider: "codex", viewColumn: 1, index: 2, label: "t", isActive: false };

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
