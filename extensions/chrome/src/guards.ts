import type { ActivateRequest, RegistryMessage } from "./protocol.js";
import { PROTOCOL_VERSION, UNBOUND_CONNECTOR_ID } from "./protocol.js";

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function text(record: UnknownRecord, key: string): string | null {
  const value = record[key];
  return typeof value === "string" ? value : null;
}

function index(record: UnknownRecord, key: string): number | null {
  const value = record[key];
  return typeof value === "number" && Number.isInteger(value) && value >= 0 ? value : null;
}

function parseActivateRequest(payload: unknown): ActivateRequest | null {
  if (!isRecord(payload)) return null;
  const requestId = text(payload, "requestId");
  const destinationId = text(payload, "destinationId");
  const expectedProvider = text(payload, "expectedProvider");
  const expectedConversationId = text(payload, "expectedConversationId");
  const destinationRevision = index(payload, "destinationRevision");
  const tabId = index(payload, "tabId");
  const windowId = index(payload, "windowId");
  if (
    requestId === null || destinationId === null || expectedProvider === null ||
    expectedConversationId === null || destinationRevision === null || tabId === null || windowId === null
  ) {
    return null;
  }
  return { requestId, destinationId, destinationRevision, tabId, windowId, expectedProvider, expectedConversationId };
}

export interface ConnectionIdentity {
  connectorId: string;
  epoch: string;
}

/**
 * Registry frames are validated like any other input. Only the registry's own error frames may
 * carry the unbound identity, since they can precede a successful hello.
 */
export function parseRegistryMessage(raw: unknown, identity: ConnectionIdentity): RegistryMessage | null {
  if (!isRecord(raw) || text(raw, "protocolVersion") !== PROTOCOL_VERSION) return null;
  const type = text(raw, "type");
  const payload = raw["payload"];
  if (type === "error" && isRecord(payload)) {
    const code = text(payload, "code");
    const message = text(payload, "message");
    return code !== null && message !== null ? { kind: "error", code, message } : null;
  }
  const bound = text(raw, "connectorId") === identity.connectorId && text(raw, "connectionEpoch") === identity.epoch;
  if (!bound || text(raw, "connectorId") === UNBOUND_CONNECTOR_ID) return null;
  switch (type) {
    case "hello.ack": return { kind: "helloAck" };
    case "snapshot.request": return { kind: "snapshotRequest" };
    case "activate.request": {
      const request = parseActivateRequest(payload);
      return request === null ? null : { kind: "activateRequest", request };
    }
    default: return null;
  }
}
