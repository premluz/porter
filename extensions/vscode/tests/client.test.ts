import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";
import { EditorClient, RETRY_DELAYS_MS, type ClientDeps, type Transport } from "../src/client.js";
import { connectorIdFor, installationIdFor } from "../src/identity.js";
import { buildReports } from "../src/snapshot.js";

const WINDOW_PATH = "/Users/example/Porter";
const installationId = installationIdFor(WINDOW_PATH);
const connectorId = connectorIdFor(installationId);

class FakeTransport implements Transport {
  sent: Array<Record<string, unknown>> = [];
  closed = false;
  private messageCallbacks: Array<(m: unknown) => void> = [];
  private closeCallbacks: Array<(r: string | undefined) => void> = [];
  send(message: unknown): void { this.sent.push(message as Record<string, unknown>); }
  close(): void { this.closed = true; }
  onMessage(callback: (m: unknown) => void): void { this.messageCallbacks.push(callback); }
  onClose(callback: (r: string | undefined) => void): void { this.closeCallbacks.push(callback); }
  receive(message: unknown): void { for (const callback of this.messageCallbacks) callback(message); }
  drop(reason?: string): void { for (const callback of this.closeCallbacks) callback(reason); }
  get types(): unknown[] { return this.sent.map((m) => m["type"]); }
}

function setup() {
  const transports: FakeTransport[] = [];
  const scheduled: Array<{ callback: () => void; delayMs: number }> = [];
  const statuses: string[] = [];
  const activations: string[] = [];
  let counter = 0;
  let tabs = buildReports(WINDOW_PATH, [{ label: "Release plan", viewColumn: 1, index: 0, isActive: true }]);
  const deps: ClientDeps = {
    window: { installationId, connectorId, folderName: "Porter" },
    connect: () => { const t = new FakeTransport(); transports.push(t); return t; },
    reports: () => tabs,
    activate: async (request) => {
      activations.push(request.requestId);
      return { requestId: request.requestId, destinationId: request.destinationId, destinationRevision: request.destinationRevision, outcome: "activated" };
    },
    randomId: () => `00000000-0000-4000-8000-${String(++counter).padStart(12, "0")}`,
    now: () => new Date("2026-10-08T07:00:00.000Z"),
    schedule: (callback, delayMs) => void scheduled.push({ callback, delayMs }),
    onStatus: (status) => void statuses.push(status.state),
  };
  return { client: new EditorClient(deps), transports, scheduled, statuses, activations, setTabs: (t: typeof tabs) => { tabs = t; } };
}

const frame = (epoch: string, type: string, payload: unknown) =>
  ({ protocolVersion: "1.0", messageId: "m", connectorId, connectionEpoch: epoch, sequence: 0, type, sentAt: "2026-10-08T07:00:00Z", payload });
const flush = () => new Promise((resolve) => setImmediate(resolve));

async function connected() {
  const ctx = setup();
  ctx.client.start();
  const transport = ctx.transports[0]!;
  const epoch = transport.sent[0]!["connectionEpoch"] as string;
  transport.receive(frame(epoch, "hello.ack", { accepted: true }));
  await flush();
  return { ...ctx, transport, epoch };
}

describe("editor client", () => {
  it("says hello as an editor connector, then reports its tabs once acknowledged", async () => {
    const { transport } = await connected();
    assert.deepEqual(transport.types, ["hello", "inventory.snapshot"]);
    const hello = transport.sent[0]!["payload"] as Record<string, unknown>;
    assert.equal(hello["connectorKind"], "vscode");
    assert.equal(hello["profileAlias"], "Porter");
    assert.equal(transport.sent[0]!["connectorId"], connectorId);
    assert.deepEqual([transport.sent[0]!["sequence"], transport.sent[1]!["sequence"]], [0, 1]);
    const snapshot = transport.sent[1]!["payload"] as { tabs: unknown[]; editorTabs: Array<{ title: string }> };
    assert.deepEqual(snapshot.tabs, []);
    assert.equal(snapshot.editorTabs[0]?.title, "Release plan");
  });

  it("reports nothing before the registry has acknowledged, and resends on request and on change", async () => {
    const early = setup();
    early.client.start();
    early.client.sendSnapshot();
    assert.deepEqual(early.transports[0]!.types, ["hello"]);
    const { client, transport, epoch, setTabs } = await connected();
    transport.receive(frame(epoch, "snapshot.request", {}));
    setTabs([]);
    client.sendSnapshot();
    assert.deepEqual(transport.types, ["hello", "inventory.snapshot", "inventory.snapshot", "inventory.snapshot"]);
    assert.equal(client.status().reported, 0);
  });

  it("answers an activation request through the activation handler", async () => {
    const { transport, epoch, activations } = await connected();
    transport.receive(frame(epoch, "activate.request", {
      requestId: "req-1", destinationId: "dest-1", destinationRevision: 4, expectedProvider: "claude-code", expectedConversationId: "c",
      editor: { workspacePath: WINDOW_PATH, viewColumn: 1, index: 0, expectedTitle: "Release plan" },
    }));
    await flush();
    assert.deepEqual(activations, ["req-1"]);
    assert.equal(transport.types.at(-1), "activate.result");
  });

  it("ignores messages for another epoch or another connector", async () => {
    const { transport, epoch, activations } = await connected();
    const request = { requestId: "x", destinationId: "d", destinationRevision: 1, expectedProvider: "claude-code", expectedConversationId: "c", editor: { workspacePath: WINDOW_PATH, viewColumn: 1, index: 0, expectedTitle: "t" } };
    transport.receive(frame("stale", "activate.request", request));
    transport.receive({ ...frame(epoch, "activate.request", request), connectorId: "vscode-other" });
    await flush();
    assert.deepEqual(activations, []);
  });

  it("retries with growing delays when the registry is not there, and resets after a success", async () => {
    const ctx = setup();
    ctx.client.start();
    for (let attempt = 0; attempt < RETRY_DELAYS_MS.length + 2; attempt += 1) {
      ctx.transports.at(-1)!.drop("Porter is not running");
      ctx.scheduled.at(-1)!.callback();
    }
    // No connection was acknowledged yet, so every scheduled callback so far is a retry.
    const delays = ctx.scheduled.map((s) => s.delayMs);
    assert.deepEqual(delays.slice(0, 5), [...RETRY_DELAYS_MS]);
    assert.equal(delays.at(-1), RETRY_DELAYS_MS.at(-1));
    ctx.transports.at(-1)!.drop("Porter is not running");
    assert.equal(ctx.client.status().detail, "Porter is not running");
    assert.equal(ctx.client.status().state, "unavailable");
    ctx.scheduled.at(-1)!.callback();
    const transport = ctx.transports.at(-1)!;
    transport.receive(frame(transport.sent[0]!["connectionEpoch"] as string, "hello.ack", {}));
    await flush();
    transport.drop();
    assert.equal(ctx.scheduled.at(-1)?.delayMs, RETRY_DELAYS_MS[0]);
  });

  it("uses a new epoch and restarts the sequence on every connection, and stop prevents reconnecting", async () => {
    const first = await connected();
    first.transport.drop();
    first.scheduled.at(-1)!.callback();
    const second = first.transports[1]!;
    assert.notEqual(second.sent[0]!["connectionEpoch"], first.epoch);
    assert.equal(second.sent[0]!["sequence"], 0);
    first.client.stop();
    assert.equal(second.closed, true);
    const before = first.transports.length;
    second.drop();
    first.scheduled.at(-1)?.callback();
    assert.equal(first.transports.length, before);
  });

  it("everything it sends satisfies the shared contract schemas", async () => {
    const { transport, epoch } = await connected();
    transport.receive(frame(epoch, "activate.request", {
      requestId: "6f1c2a3e-8888-4a1a-8a1a-000000000002", destinationId: "6f1c2a3e-5555-4a1a-8a1a-000000000009", destinationRevision: 1,
      expectedProvider: "claude-code", expectedConversationId: "c", editor: { workspacePath: WINDOW_PATH, viewColumn: 1, index: 0, expectedTitle: "Release plan" },
    }));
    await flush();
    const file = join(mkdtempSync(join(tmpdir(), "porter-vscode-wire-")), "messages.json");
    writeFileSync(file, JSON.stringify(transport.sent));
    const script = join(__dirname, "../../../../packages/contracts/scripts/validate-messages.mjs");
    assert.match(execFileSync("node", [script, file], { encoding: "utf8" }), /3 envelope\(s\) satisfy the contract/);
  });
});
