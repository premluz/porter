import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { activate, type ActivationDeps } from "../src/activation.js";
import type { TabLike } from "../src/inventory.js";
import type { ActivateRequest } from "../src/protocol.js";

const request: ActivateRequest = {
  requestId: "r1", destinationId: "d1", destinationRevision: 3, tabId: 42, windowId: 7,
  expectedProvider: "claude", expectedConversationId: "chat-a",
};

function deps(tab: TabLike | undefined | Error) {
  const focused: Array<[number, number]> = [];
  const logged: string[] = [];
  const api: ActivationDeps = {
    getTab: async () => {
      if (tab instanceof Error) throw tab;
      return tab;
    },
    focusTab: async (tabId, windowId) => void focused.push([tabId, windowId]),
    log: (message) => void logged.push(message),
  };
  return { api, focused, logged };
}

describe("activation", () => {
  it("focuses the tab in the window it is in now, not the registry's hint", async () => {
    const { api, focused } = deps({ id: 42, windowId: 99, url: "https://claude.ai/chat/chat-a" });
    const result = await activate(request, api);
    assert.equal(result.outcome, "activated");
    assert.deepEqual(focused, [[42, 99]]);
    assert.equal(result.requestId, "r1");
    assert.equal(result.destinationRevision, 3);
  });

  it("reports a closed tab as gone and focuses nothing", async () => {
    const { api, focused } = deps(undefined);
    assert.equal((await activate(request, api)).outcome, "targetGone");
    assert.deepEqual(focused, []);
  });

  it("refuses a tab that now shows a different chat", async () => {
    const { api, focused } = deps({ id: 42, windowId: 7, url: "https://claude.ai/chat/chat-b" });
    assert.equal((await activate(request, api)).outcome, "targetChanged");
    assert.deepEqual(focused, []);
  });

  it("refuses a tab that navigated away from the provider", async () => {
    const { api } = deps({ id: 42, windowId: 7, url: "https://example.com/" });
    assert.equal((await activate(request, api)).outcome, "targetChanged");
  });

  it("reports a hidden URL as a permission problem", async () => {
    const { api } = deps({ id: 42, windowId: 7 });
    assert.equal((await activate(request, api)).outcome, "permissionDenied");
  });

  it("refuses a request for another provider", async () => {
    const { api } = deps({ id: 42, windowId: 7, url: "https://claude.ai/chat/chat-a" });
    const other = { ...request, expectedProvider: "chatgpt" };
    assert.equal((await activate(other, api)).outcome, "targetChanged");
  });

  it("reports an unexpected browser failure instead of claiming success", async () => {
    const { api, logged } = deps(new Error("boom"));
    assert.equal((await activate(request, api)).outcome, "failed");
    assert.equal(logged.length, 1);
  });
});

describe("activation across providers", () => {
  it("focuses a ChatGPT tab only for a ChatGPT request, and never across providers", async () => {
    const chatgpt = { ...request, expectedProvider: "chatgpt", expectedConversationId: "c-1" };
    const right = deps({ id: 42, windowId: 7, url: "https://chatgpt.com/c/c-1" });
    assert.equal((await activate(chatgpt, right.api)).outcome, "activated");
    const wrongProvider = deps({ id: 42, windowId: 7, url: "https://claude.ai/chat/c-1" });
    assert.equal((await activate(chatgpt, wrongProvider.api)).outcome, "targetChanged");
    assert.deepEqual(wrongProvider.focused, []);
    const asClaude = deps({ id: 42, windowId: 7, url: "https://chatgpt.com/c/chat-a" });
    assert.equal((await activate(request, asClaude.api)).outcome, "targetChanged");
  });
});
