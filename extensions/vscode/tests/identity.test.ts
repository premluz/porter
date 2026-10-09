import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { connectorIdFor, conversationIdFor, installationIdFor } from "../src/identity.js";
import { RecencyTracker } from "../src/recency.js";
import { ADAPTER_VERSION, ADAPTER_VERSIONS, MAX_PAYLOAD_BYTES, buildReports, fitSnapshot, type EditorTabReport } from "../src/snapshot.js";
import type { EditorTab } from "../src/tabs.js";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

describe("window and conversation identity", () => {
  it("derives a stable, valid UUID per folder and a different one for another folder", () => {
    const one = installationIdFor("/Users/a/Porter");
    assert.match(one, UUID);
    assert.equal(one, installationIdFor("/Users/a/Porter"));
    assert.notEqual(one, installationIdFor("/Users/a/Merlin"));
    assert.equal(connectorIdFor(one), `vscode-${one}`);
  });

  it("derives a 16-character conversation ID that changes with folder, title and ordinal", () => {
    const base = conversationIdFor("/p", "claude-code", "Notes", 0);
    assert.match(base, /^[0-9a-f]{16}$/);
    assert.equal(base, conversationIdFor("/p", "claude-code", "Notes", 0));
    for (const other of [conversationIdFor("/q", "claude-code", "Notes", 0), conversationIdFor("/p", "claude-code", "Other", 0), conversationIdFor("/p", "claude-code", "Notes", 1), conversationIdFor("/p", "codex", "Notes", 0)]) {
      assert.notEqual(base, other);
    }
  });

  it("does not confuse a title with an ordinal by concatenation", () => {
    assert.notEqual(conversationIdFor("/p", "claude-code", "a1", 0), conversationIdFor("/p", "claude-code", "a", 10));
  });
});

describe("snapshots", () => {
  const tab = (label: string, viewColumn = 1, index = 0, provider = "claude-code", isActive = false): EditorTab =>
    ({ provider, label, viewColumn, index, isActive });
  const build = (path: string, tabs: EditorTab[], tracker = new RecencyTracker()) => buildReports(path, tabs, tracker, 5_000);

  it("tells same-titled tabs apart by order, and keeps provider and version constants", () => {
    const reports = build("/p", [tab("Notes", 1, 0), tab("Other", 1, 1), tab("Notes", 2, 0)]);
    assert.equal(new Set(reports.map((r) => r.providerConversationId)).size, 3);
    assert.equal(reports[0]?.providerConversationId, conversationIdFor("/p", "claude-code", "Notes", 0));
    assert.equal(reports[2]?.providerConversationId, conversationIdFor("/p", "claude-code", "Notes", 1));
    assert.ok(reports.every((r) => r.provider === "claude-code" && r.workspacePath === "/p"));
    assert.equal(ADAPTER_VERSION, "0.2.0");
  });

  it("keeps same-titled Claude Code and Codex tabs apart, and declares both providers", () => {
    const reports = build("/p", [tab("Notes", 1, 0, "claude-code"), tab("Notes", 1, 1, "codex")]);
    assert.deepEqual(reports.map((r) => r.provider), ["claude-code", "codex"]);
    assert.notEqual(reports[0]?.providerConversationId, reports[1]?.providerConversationId);
    assert.deepEqual(Object.keys(ADAPTER_VERSIONS).sort(), ["claude-code", "codex"]);
  });

  it("reports when a tab was last used, once it has been, and omits the field otherwise", () => {
    const first = build("/p", [tab("A", 1, 0, "claude-code", true), tab("B", 1, 1)]);
    assert.equal(first[0]?.lastActiveAt, new Date(5_000).toISOString());
    assert.equal(first[1] !== undefined && "lastActiveAt" in first[1], false);
  });

  it("falls back to a readable title and truncates very long ones", () => {
    assert.equal(build("/p", [tab("")])[0]?.title, "Untitled conversation");
    assert.equal(build("/p", [tab("x".repeat(600))])[0]?.title.length, 512);
  });

  it("drops the tabs that do not fit rather than sending an oversized frame, and says how many", () => {
    const path = "/" + "d".repeat(1000);
    const many: EditorTabReport[] = Array.from({ length: 150 }, (_, i) => ({
      provider: "claude-code", providerConversationId: String(i).padStart(16, "0"), title: "t", workspacePath: path, viewColumn: 1, index: i % 9,
    }));
    const fitted = fitSnapshot(many);
    assert.ok(fitted.tabs.length > 0 && fitted.tabs.length < many.length);
    assert.equal(fitted.tabs.length + fitted.dropped, many.length);
    assert.ok(Buffer.byteLength(JSON.stringify(fitted.tabs)) <= MAX_PAYLOAD_BYTES);
  });

  it("keeps everything when it fits, up to the registry's tab limit", () => {
    const small = Array.from({ length: 260 }, (_, i) => ({
      provider: "claude-code", providerConversationId: String(i).padStart(16, "0"), title: "t", workspacePath: "/p", viewColumn: 1, index: 0,
    }));
    const fitted = fitSnapshot(small);
    assert.equal(fitted.tabs.length, 200);
    assert.equal(fitted.dropped, 60);
    assert.deepEqual(fitSnapshot([]), { tabs: [], dropped: 0 });
  });
});
