import { endianness } from "node:os";
import type { EditorTabReport } from "./snapshot.js";

export const PROTOCOL_VERSION = "1.0";
export const UNBOUND_CONNECTOR_ID = "unbound";
export const MAX_OUTBOUND_BYTES = 64 * 1024;
export const MAX_INBOUND_BYTES = 1024 * 1024;
const PREFIX_BYTES = 4;
const LITTLE_ENDIAN = endianness() === "LE";

export interface EditorTarget {
  workspacePath: string;
  viewColumn: number;
  index: number;
  expectedTitle: string;
}

export interface ActivateRequest {
  requestId: string;
  destinationId: string;
  destinationRevision: number;
  expectedProvider: string;
  expectedConversationId: string;
  editor: EditorTarget;
}

export type ActivationOutcome = "activated" | "targetGone" | "targetChanged" | "unsupported" | "failed";

export interface ActivationResultPayload {
  requestId: string;
  destinationId: string;
  destinationRevision: number;
  outcome: ActivationOutcome;
}

export type OutboundMessage =
  | { type: "hello"; payload: { installationId: string; profileAlias?: string; connectorKind: "vscode"; adapterVersions: Record<string, string> } }
  | { type: "inventory.snapshot"; payload: { tabs: []; editorTabs: EditorTabReport[] } }
  | { type: "heartbeat"; payload: Record<string, never> }
  | { type: "activate.result"; payload: ActivationResultPayload };

export type RegistryMessage =
  | { kind: "helloAck" }
  | { kind: "snapshotRequest" }
  | { kind: "activateRequest"; request: ActivateRequest }
  | { kind: "error"; code: string; message: string };

/** The same framing Chrome uses: a 32-bit length in the machine's byte order, then UTF-8 JSON. */
export function encodeFrame(message: unknown): Buffer {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  if (body.length > MAX_OUTBOUND_BYTES) throw new RangeError(`frame of ${body.length} bytes exceeds ${MAX_OUTBOUND_BYTES}`);
  const prefix = Buffer.alloc(PREFIX_BYTES);
  if (LITTLE_ENDIAN) prefix.writeUInt32LE(body.length); else prefix.writeUInt32BE(body.length);
  return Buffer.concat([prefix, body]);
}

export class FrameTooLarge extends Error {}

/** Reassembles frames from arbitrary chunks; an oversized declared length is refused before reading it. */
export class FrameDecoder {
  private pending = Buffer.alloc(0);

  push(chunk: Buffer): Buffer[] {
    this.pending = Buffer.concat([this.pending, chunk]);
    const frames: Buffer[] = [];
    for (;;) {
      if (this.pending.length < PREFIX_BYTES) return frames;
      const length = LITTLE_ENDIAN ? this.pending.readUInt32LE(0) : this.pending.readUInt32BE(0);
      if (length > MAX_INBOUND_BYTES) throw new FrameTooLarge(`declared frame of ${length} bytes`);
      if (this.pending.length < PREFIX_BYTES + length) return frames;
      frames.push(this.pending.subarray(PREFIX_BYTES, PREFIX_BYTES + length));
      this.pending = this.pending.subarray(PREFIX_BYTES + length);
    }
  }
}
