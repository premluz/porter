import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { DUPLICATE_RETRY_DELAY_MS } from "../src/bridge.js";
import { CONNECTOR_ID, connected, flush, registryFrame, setup } from "./support.js";

describe("bridge client", () => {
  it("opens with hello at sequence 0, then sends a snapshot after the acknowledgment", async () => {
    const { port } = await connected({ alias: "Work" });
    assert.deepEqual(port.types, ["hello", "inventory.snapshot"]);
    assert.equal(port.sent[0]!["sequence"], 0);
    assert.equal(port.sent[1]!["sequence"], 1);
    assert.equal(port.sent[0]!["connectorId"], CONNECTOR_ID);
    const hello = port.sent[0]!["payload"] as Record<string, unknown>;
    assert.equal(hello["profileAlias"], "Work");
  });

  it("omits the alias entirely when none is set", async () => {
    const { port } = await connected();
    assert.equal("profileAlias" in (port.sent[0]!["payload"] as object), false);
  });

  it("uses a new epoch and restarts the sequence on every connection", async () => {
    const first = await connected();
    first.port.drop();
    await first.client.ensureConnected();
    const second = first.ports[1]!;
    assert.notEqual(second.sent[0]!["connectionEpoch"], first.epoch);
    assert.equal(second.sent[0]!["sequence"], 0);
  });

  it("answers a snapshot request and an activation request", async () => {
    const { port, epoch, activations } = await connected();
    port.receive(registryFrame(epoch, "snapshot.request", {}));
    port.receive(registryFrame(epoch, "activate.request", {
      requestId: "req-1", destinationId: "dest-1", destinationRevision: 2, tabId: 42, windowId: 7,
      expectedProvider: "claude", expectedConversationId: "chat-a",
    }));
    await flush();
    assert.deepEqual(port.types, ["hello", "inventory.snapshot", "inventory.snapshot", "activate.result"]);
    assert.deepEqual(activations, ["req-1"]);
  });

  it("ignores registry messages for another connector or epoch", async () => {
    const { port, epoch, activations } = await connected();
    const request = { requestId: "req-x", destinationId: "d", destinationRevision: 1, tabId: 1, windowId: 1,
      expectedProvider: "claude", expectedConversationId: "chat-a" };
    port.receive(registryFrame(epoch, "activate.request", request, "chrome-someone-else"));
    port.receive(registryFrame("stale-epoch", "activate.request", request));
    port.receive(registryFrame("unbound", "activate.request", request, "unbound"));
    port.receive({ not: "an envelope" });
    await flush();
    assert.deepEqual(activations, []);
  });

  it("rejects malformed activation payloads", async () => {
    const { port, epoch, activations } = await connected();
    port.receive(registryFrame(epoch, "activate.request", { requestId: "r", tabId: -1 }));
    await flush();
    assert.deepEqual(activations, []);
  });

  it("reports unavailable when the host never answered, disconnected after it had", async () => {
    const never = setup();
    await never.client.ensureConnected();
    never.setReason("Specified native messaging host not found.");
    never.ports[0]!.drop();
    assert.equal(never.client.status().state, "unavailable");
    assert.match(never.client.status().detail ?? "", /not found/);
    const had = await connected();
    had.port.drop();
    assert.equal(had.client.status().state, "disconnected");
  });

  it("retries a duplicate-installation refusal a bounded number of times", async () => {
    const { client, ports, scheduled } = setup();
    for (let attempt = 0; attempt < 7; attempt += 1) {
      await client.ensureConnected();
      const port = ports.at(-1)!;
      port.receive({ protocolVersion: "1.0", type: "error", payload: { code: "duplicateInstallation", message: "dup" } });
      port.drop();
      scheduled.at(-1)?.callback();
      await flush();
    }
    assert.equal(scheduled.filter((s) => s.delayMs === DUPLICATE_RETRY_DELAY_MS).length, 5);
  });

  it("ignores events from a port that was already replaced", async () => {
    const { client, ports } = setup();
    await client.ensureConnected();
    const old = ports[0]!;
    client.disconnect();
    await client.ensureConnected();
    old.drop();
    assert.equal(client.status().state, "connecting");
  });

  it("does not send a snapshot before the registry has acknowledged hello", async () => {
    const { client, ports } = setup();
    await client.ensureConnected();
    await client.sendSnapshot();
    assert.deepEqual(ports[0]!.types, ["hello"]);
  });
});
