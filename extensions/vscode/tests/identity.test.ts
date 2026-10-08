import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { connectorIdFor, conversationIdFor, installationIdFor } from "../src/identity.js";
import { ADAPTER_VERSION, MAX_PAYLOAD_BYTES, PROVIDER, buildReports, fitSnapshot, type EditorTabReport } from "../src/snapshot.js";
import type { ClaudeTab } from "../src/tabs.js";

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
    const base = conversationIdFor("/p", "Notes", 0);
    assert.match(base, /^[0-9a-f]{16}$/);
    assert.equal(base, conversationIdFor("/p", "Notes", 0));
    for (const other of [conversationIdFor("/q", "Notes", 0), conversationIdFor("/p", "Other", 0), conversationIdFor("/p", "Notes", 1)]) {
      assert.notEqual(base, other);
    }
  });

  it("does not confuse a title with an ordinal by concatenation", () => {
    assert.notEqual(conversationIdFor("/p", "a1", 0), conversationIdFor("/p", "a", 10));
  });
});

describe("snapshots", () => {
  const tab = (label: string, viewColumn = 1, index = 0): ClaudeTab => ({ label, viewColumn, index, isActive: false });

  it("tells same-titled tabs apart by order, and keeps provider and version constants", () => {
    const reports = buildReports("/p", [tab("Notes", 1, 0), tab("Other", 1, 1), tab("Notes", 2, 0)]);
    assert.equal(new Set(reports.map((r) => r.providerConversationId)).size, 3);
    assert.equal(reports[0]?.providerConversationId, conversationIdFor("/p", "Notes", 0));
    assert.equal(reports[2]?.providerConversationId, conversationIdFor("/p", "Notes", 1));
    assert.ok(reports.every((r) => r.provider === PROVIDER && r.workspacePath === "/p"));
    assert.equal(ADAPTER_VERSION, "0.1.0");
  });

  it("falls back to a readable title and truncates very long ones", () => {
    assert.equal(buildReports("/p", [tab("")])[0]?.title, "Untitled conversation");
    assert.equal(buildReports("/p", [tab("x".repeat(600))])[0]?.title.length, 512);
  });

  it("drops the tabs that do not fit rather than sending an oversized frame, and says how many", () => {
    const path = "/" + "d".repeat(1000);
    const many: EditorTabReport[] = Array.from({ length: 150 }, (_, i) => ({
      provider: PROVIDER, providerConversationId: String(i).padStart(16, "0"), title: "t", workspacePath: path, viewColumn: 1, index: i % 9,
    }));
    const fitted = fitSnapshot(many);
    assert.ok(fitted.tabs.length > 0 && fitted.tabs.length < many.length);
    assert.equal(fitted.tabs.length + fitted.dropped, many.length);
    assert.ok(Buffer.byteLength(JSON.stringify(fitted.tabs)) <= MAX_PAYLOAD_BYTES);
  });

  it("keeps everything when it fits, up to the registry's tab limit", () => {
    const small = Array.from({ length: 260 }, (_, i) => ({
      provider: PROVIDER, providerConversationId: String(i).padStart(16, "0"), title: "t", workspacePath: "/p", viewColumn: 1, index: 0,
    }));
    const fitted = fitSnapshot(small);
    assert.equal(fitted.tabs.length, 200);
    assert.equal(fitted.dropped, 60);
    assert.deepEqual(fitSnapshot([]), { tabs: [], dropped: 0 });
  });
});
