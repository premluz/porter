import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";
import { connected, flush, registryFrame } from "./support.js";

describe("wire format", () => {
  it("produces messages that satisfy the shared contract schemas", async () => {
    const { port, epoch } = await connected({ alias: "Work" });
    port.receive(registryFrame(epoch, "activate.request", {
      requestId: "6f1c2a3e-8888-4a1a-8a1a-000000000001", destinationId: "6f1c2a3e-5555-4a1a-8a1a-000000000001",
      destinationRevision: 1, tabId: 42, windowId: 7, expectedProvider: "claude", expectedConversationId: "chat-a",
    }));
    await flush();
    const directory = mkdtempSync(join(tmpdir(), "porter-wire-"));
    const file = join(directory, "messages.json");
    writeFileSync(file, JSON.stringify(port.sent));
    const script = join(import.meta.dirname, "../../../../packages/contracts/scripts/validate-messages.mjs");
    const output = execFileSync("node", [script, file], { encoding: "utf8" });
    assert.match(output, /3 envelope\(s\) satisfy the contract/);
  });
});
