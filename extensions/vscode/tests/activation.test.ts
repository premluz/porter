import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { activate, type ActivationApi } from "../src/activation.js";
import { conversationIdFor } from "../src/identity.js";
import type { ActivateRequest } from "../src/protocol.js";
import type { GroupLike } from "../src/tabs.js";

const VIEW = "mainThreadWebview-claudeVSCodePanel";
const claude = (label: string, active = false) => ({ label, isActive: active, viewType: VIEW });
const codex = (label: string, active = false) => ({ label, isActive: active, viewType: "chatgpt.conversationEditor" });
const file = (label: string, active = false) => ({ label, isActive: active, viewType: undefined });

function setup(groups: GroupLike[], afterCommands?: GroupLike[], workspace = "/p") {
  const commands: string[] = [];
  let current = groups;
  const api: ActivationApi = {
    groups: () => current,
    workspacePath: () => workspace,
    runCommand: async (command) => {
      commands.push(command);
      if (afterCommands !== undefined) current = afterCommands;
    },
    settle: async () => undefined,
    log: () => undefined,
  };
  return { api, commands };
}

const request = (overrides: Partial<ActivateRequest["editor"]> = {}, conversation = conversationIdFor("/p", "claude-code", "Notes", 0)): ActivateRequest => ({
  requestId: "r", destinationId: "d", destinationRevision: 3, expectedProvider: "claude-code", expectedConversationId: conversation,
  editor: { workspacePath: "/p", viewColumn: 1, index: 1, expectedTitle: "Notes", ...overrides },
});

describe("activation in a window", () => {
  const before: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts", true), claude("Notes")] }];
  const after: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts"), claude("Notes", true)] }];

  it("brings the tab forward and reports activated only after the tab API confirms it", async () => {
    const { api, commands } = setup(before, after);
    const result = await activate(request(), api);
    assert.equal(result.outcome, "activated");
    assert.deepEqual(commands, ["workbench.action.focusFirstEditorGroup", "workbench.action.openEditorAtIndex2"]);
    assert.deepEqual([result.requestId, result.destinationId, result.destinationRevision], ["r", "d", 3]);
  });

  it("reports failed when the commands run but the tab does not come forward", async () => {
    assert.equal((await activate(request(), setup(before, before).api)).outcome, "failed");
  });

  it("does nothing and reports activated when the tab is already in front", async () => {
    const front: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts"), claude("Notes", true)] }];
    const { api, commands } = setup(front);
    assert.equal((await activate(request(), api)).outcome, "activated");
    assert.deepEqual(commands, []);
  });

  it("refuses a closed tab, a renamed tab and an ambiguous one without touching anything", async () => {
    const closed = setup([{ viewColumn: 1, tabs: [file("a.ts", true)] }]);
    assert.equal((await activate(request(), closed.api)).outcome, "targetGone");
    const renamed = setup([{ viewColumn: 1, tabs: [file("a.ts", true), claude("Renamed")] }]);
    assert.equal((await activate(request(), renamed.api)).outcome, "targetGone");
    const twin: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts", true), claude("Notes"), claude("Notes")] }, { viewColumn: 2, tabs: [claude("Notes")] }];
    const moved = setup(twin);
    assert.equal((await activate(request({ viewColumn: 5, index: 5 }), moved.api)).outcome, "targetChanged");
    for (const { commands } of [closed, renamed, moved]) assert.deepEqual(commands, []);
  });

  it("finds a tab that moved when its title is unique, but only if its identity still matches", async () => {
    const shifted: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts", true), file("b.ts"), claude("Notes")] }];
    const afterShift: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts"), file("b.ts"), claude("Notes", true)] }];
    assert.equal((await activate(request(), setup(shifted, afterShift).api)).outcome, "activated");
    assert.equal((await activate(request({}, "deadbeefdeadbeef"), setup(shifted, afterShift).api)).outcome, "targetChanged");
  });

  it("refuses requests for another provider or another window's folder", async () => {
    const { api, commands } = setup(before, after);
    assert.equal((await activate({ ...request(), expectedProvider: "claude" }, api)).outcome, "targetGone");
    assert.equal((await activate(request({ workspacePath: "/other" }), api)).outcome, "targetChanged");
    assert.deepEqual(commands, []);
  });

  it("says unsupported for positions the built-in commands cannot reach, and failed when a command throws", async () => {
    const deep: GroupLike[] = [{ viewColumn: 1, tabs: [...Array.from({ length: 9 }, (_, i) => file(`f${i}`, i === 0)), claude("Notes")] }];
    assert.equal((await activate(request({ index: 9 }), setup(deep).api)).outcome, "unsupported");
    const throwing = setup(before, after);
    throwing.api.runCommand = async () => { throw new Error("boom"); };
    assert.equal((await activate(request(), throwing.api)).outcome, "failed");
  });

  it("brings a Codex tab forward, and never lets a request for one provider act on the other's tab", async () => {
    const mixed: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts", true), claude("Notes"), codex("Notes")] }];
    const codexFront: GroupLike[] = [{ viewColumn: 1, tabs: [file("a.ts"), claude("Notes"), codex("Notes", true)] }];
    const codexRequest: ActivateRequest = {
      ...request({ index: 2 }, conversationIdFor("/p", "codex", "Notes", 0)), expectedProvider: "codex",
    };
    const ok = setup(mixed, codexFront);
    assert.equal((await activate(codexRequest, ok.api)).outcome, "activated");
    assert.deepEqual(ok.commands, ["workbench.action.focusFirstEditorGroup", "workbench.action.openEditorAtIndex3"]);
    // The same request with the other provider's identity must not be satisfied by the same-titled tab.
    const crossed = setup(mixed, codexFront);
    const wrongProvider: ActivateRequest = { ...request({ index: 2 }, conversationIdFor("/p", "codex", "Notes", 0)), expectedProvider: "claude-code" };
    assert.equal((await activate(wrongProvider, crossed.api)).outcome, "targetChanged");
    assert.deepEqual(crossed.commands, []);
  });
});
