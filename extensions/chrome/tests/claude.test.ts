import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { cleanTitle, matchConversation } from "../src/adapters/claude.js";
import { buildReports, grantedPatterns, missingTabIds, reportFor, urlShape } from "../src/inventory.js";
import { ADAPTERS, ADAPTER_VERSIONS, adapterForProvider, recognise } from "../src/adapters/registry.js";
import { chatgptAdapter } from "../src/adapters/chatgpt.js";

describe("claude adapter", () => {
  it("identifies a chat from the URL alone and drops query and fragment", () => {
    const match = matchConversation("https://claude.ai/chat/5c0e1a52-aaaa-bbbb-cccc-0123456789ab?x=1#frag");
    assert.deepEqual(match, {
      providerConversationId: "5c0e1a52-aaaa-bbbb-cccc-0123456789ab",
      canonicalUrl: "https://claude.ai/chat/5c0e1a52-aaaa-bbbb-cccc-0123456789ab",
    });
  });

  it("rejects look-alike and non-chat addresses", () => {
    const rejected = [
      undefined,
      "not a url",
      "http://claude.ai/chat/abc",
      "https://claude.ai/",
      "https://claude.ai/new",
      "https://claude.ai/chat/",
      "https://claude.ai/chat/abc/extra",
      "https://claude.ai/project/abc",
      "https://claude.ai:8443/chat/abc",
      "https://www.claude.ai/chat/abc",
      "https://claude.ai.evil.example/chat/abc",
      "https://claude.ai@evil.example/chat/abc",
      "https://evil.example/chat/abc?u=https://claude.ai/chat/abc",
      "https://claude.ai/chat/abc%2F..%2Fdef",
      "javascript:alert(1)",
    ];
    for (const url of rejected) assert.equal(matchConversation(url), null, String(url));
  });

  it("strips the provider suffix and never returns an empty title", () => {
    assert.equal(cleanTitle("Release plan - Claude"), "Release plan");
    assert.equal(cleanTitle("Release plan | Claude"), "Release plan");
    assert.equal(cleanTitle("Claude"), "Untitled conversation");
    assert.equal(cleanTitle(undefined), "Untitled conversation");
    assert.equal(cleanTitle("x".repeat(600)).length, 512);
  });
});

describe("inventory", () => {
  const chat = (id: number, title = "Plan - Claude", url = `https://claude.ai/chat/c${id}`) =>
    ({ id, windowId: 1, url, title });

  it("reports only recognized tabs, with no URL query data", () => {
    const reports = buildReports([
      chat(2), { id: 3, windowId: 1, url: "https://mail.example/inbox", title: "Inbox" }, chat(1),
    ]);
    assert.deepEqual(reports.map((r) => r.tabId), [1, 2]);
    assert.ok(reports.every((r) => !r.canonicalUrl.includes("?")));
  });

  it("skips tabs whose URL is hidden because permission is missing", () => {
    assert.equal(reportFor({ id: 1, windowId: 1, title: "Plan" }), null);
  });

  it("caps the snapshot at the contract limit", () => {
    const many = Array.from({ length: 250 }, (_, i) => chat(i));
    assert.equal(buildReports(many).length, 200);
  });

  it("keeps duplicate tabs of one chat as separate reports", () => {
    const reports = buildReports([
      { id: 1, windowId: 1, url: "https://claude.ai/chat/same", title: "Plan" },
      { id: 2, windowId: 2, url: "https://claude.ai/chat/same", title: "Plan" },
    ]);
    assert.equal(reports.length, 2);
  });
});


describe("adapter registry", () => {
  it("declares every adapter's version to the registry, and no two share a provider", () => {
    assert.deepEqual(Object.keys(ADAPTER_VERSIONS).sort(), ADAPTERS.map((a) => a.provider).sort());
    assert.equal(new Set(ADAPTERS.map((a) => a.provider)).size, ADAPTERS.length);
  });

  it("routes each URL to exactly one provider and ignores the rest", () => {
    assert.equal(recognise("https://claude.ai/chat/abc")?.adapter.provider, "claude");
    assert.equal(recognise("https://chatgpt.com/c/abc")?.adapter.provider, "chatgpt");
    assert.equal(recognise("https://example.com/c/abc"), null);
    assert.equal(recognise("https://claude.ai/c/abc"), null);
    assert.equal(recognise("https://chatgpt.com/chat/abc"), null);
  });

  it("rejects look-alike chatgpt addresses", () => {
    const rejected = [
      "http://chatgpt.com/c/abc", "https://chatgpt.com/c/", "https://chatgpt.com/c/abc/extra",
      "https://chatgpt.com.evil.example/c/abc", "https://chatgpt.com@evil.example/c/abc",
      "https://chatgpt.com:8443/c/abc", "https://www.chatgpt.com/c/abc",
    ];
    for (const url of rejected) assert.equal(chatgptAdapter.match(url), null, url);
  });

  it("marks unchecked providers as unverified", () => {
    assert.equal(adapterForProvider("claude")?.verified, true);
    assert.equal(adapterForProvider("chatgpt")?.verified, false);
    assert.equal(adapterForProvider("unknown"), undefined);
  });

  it("only queries sites the user granted", () => {
    assert.deepEqual(grantedPatterns(undefined), []);
    assert.deepEqual(grantedPatterns(["https://example.com/*"]), []);
    assert.deepEqual(grantedPatterns(["https://chatgpt.com/*"]), ["https://chatgpt.com/*"]);
    assert.deepEqual(
      grantedPatterns(["https://chatgpt.com/*", "https://claude.ai/*"]).sort(),
      ["https://chatgpt.com/*", "https://claude.ai/*"],
    );
  });
});


describe("dropout diagnostics", () => {
  it("blanks identifiers so a logged address cannot identify a chat", () => {
    assert.equal(urlShape("https://claude.ai/chat/32d0b096-f463-85b5-a77f-1b7fd27d93d8?x=1#y"), "https://claude.ai/chat/<id>");
    assert.equal(urlShape("https://claude.ai/new"), "https://claude.ai/new");
    assert.equal(urlShape(undefined), "(no url visible)");
    assert.equal(urlShape("not a url"), "(unparseable url)");
  });

  it("lists exactly the tabs that left the list", () => {
    const report = (tabId: number) => ({ tabId, windowId: 1, provider: "claude", providerConversationId: "c", title: "t", canonicalUrl: "https://claude.ai/chat/c" });
    assert.deepEqual(missingTabIds(new Set([3, 1, 2]), [report(2)]), [1, 3]);
    assert.deepEqual(missingTabIds(new Set(), [report(2)]), []);
    assert.deepEqual(missingTabIds(new Set([2]), [report(2)]), []);
  });
});
