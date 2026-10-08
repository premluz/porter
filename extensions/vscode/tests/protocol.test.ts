import assert from "node:assert/strict";
import { endianness } from "node:os";
import { describe, it } from "node:test";
import { parseRegistryMessage } from "../src/guards.js";
import { FrameDecoder, FrameTooLarge, MAX_INBOUND_BYTES, MAX_OUTBOUND_BYTES, encodeFrame } from "../src/protocol.js";

describe("framing", () => {
  it("round-trips a message, in one chunk or byte by byte", () => {
    const frame = encodeFrame({ a: 1, text: "héllo" });
    assert.deepEqual(JSON.parse(new FrameDecoder().push(frame)[0]?.toString("utf8") ?? ""), { a: 1, text: "héllo" });
    const decoder = new FrameDecoder();
    const out: Buffer[] = [];
    for (const byte of frame) out.push(...decoder.push(Buffer.from([byte])));
    assert.equal(out.length, 1);
  });

  it("separates two frames that arrive together", () => {
    const frames = new FrameDecoder().push(Buffer.concat([encodeFrame({ n: 1 }), encodeFrame({ n: 2 })]));
    assert.deepEqual(frames.map((f) => JSON.parse(f.toString("utf8"))), [{ n: 1 }, { n: 2 }]);
  });

  it("refuses an oversized declared length before waiting for the body", () => {
    const prefix = Buffer.alloc(4);
    if (endianness() === "LE") prefix.writeUInt32LE(MAX_INBOUND_BYTES + 1); else prefix.writeUInt32BE(MAX_INBOUND_BYTES + 1);
    assert.throws(() => new FrameDecoder().push(prefix), FrameTooLarge);
  });

  it("refuses to send a frame over the registry's limit", () => {
    assert.throws(() => encodeFrame({ text: "x".repeat(MAX_OUTBOUND_BYTES) }), RangeError);
  });
});

describe("registry messages", () => {
  const identity = { connectorId: "vscode-abc", epoch: "e1" };
  const frame = (type: string, payload: unknown, connectorId = "vscode-abc", epoch = "e1") =>
    ({ protocolVersion: "1.0", type, connectorId, connectionEpoch: epoch, payload });
  const request = {
    requestId: "r", destinationId: "d", destinationRevision: 2, expectedProvider: "claude-code", expectedConversationId: "c",
    editor: { workspacePath: "/p", viewColumn: 1, index: 0, expectedTitle: "t" },
  };

  it("accepts an acknowledgment, a snapshot request and a well-formed activation request", () => {
    assert.deepEqual(parseRegistryMessage(frame("hello.ack", {}), identity), { kind: "helloAck" });
    assert.deepEqual(parseRegistryMessage(frame("snapshot.request", {}), identity), { kind: "snapshotRequest" });
    assert.deepEqual(parseRegistryMessage(frame("activate.request", request), identity), { kind: "activateRequest", request });
  });

  it("refuses another connector, another epoch, the unbound identity, a wrong version and malformed requests", () => {
    assert.equal(parseRegistryMessage(frame("hello.ack", {}, "vscode-other"), identity), null);
    assert.equal(parseRegistryMessage(frame("hello.ack", {}, "vscode-abc", "old"), identity), null);
    assert.equal(parseRegistryMessage(frame("hello.ack", {}, "unbound"), { connectorId: "unbound", epoch: "e1" }), null);
    assert.equal(parseRegistryMessage({ ...frame("hello.ack", {}), protocolVersion: "2.0" }, identity), null);
    assert.equal(parseRegistryMessage(frame("activate.request", { ...request, editor: undefined }), identity), null);
    assert.equal(parseRegistryMessage(frame("activate.request", { ...request, editor: { ...request.editor, index: -1 } }), identity), null);
    assert.equal(parseRegistryMessage(frame("activate.request", { ...request, destinationRevision: "2" }), identity), null);
    assert.equal(parseRegistryMessage(frame("something.else", {}), identity), null);
    assert.equal(parseRegistryMessage("not an object", identity), null);
  });

  it("accepts the registry's own error frames even though they carry no bound identity", () => {
    const error = { protocolVersion: "1.0", type: "error", connectorId: "unbound", connectionEpoch: "none", payload: { code: "duplicateInstallation", message: "m" } };
    assert.deepEqual(parseRegistryMessage(error, identity), { kind: "error", code: "duplicateInstallation", message: "m" });
  });
});
