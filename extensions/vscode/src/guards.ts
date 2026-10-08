import { PROTOCOL_VERSION, UNBOUND_CONNECTOR_ID, type ActivateRequest, type RegistryMessage } from "./protocol.js";

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function text(record: UnknownRecord, key: string): string | null {
  const value = record[key];
  return typeof value === "string" ? value : null;
}

function whole(record: UnknownRecord, key: string): number | null {
  const value = record[key];
  return typeof value === "number" && Number.isInteger(value) && value >= 0 ? value : null;
}

function parseRequest(payload: unknown): ActivateRequest | null {
  if (!isRecord(payload) || !isRecord(payload["editor"])) return null;
  const editor = payload["editor"];
  const fields = {
    requestId: text(payload, "requestId"), destinationId: text(payload, "destinationId"),
    expectedProvider: text(payload, "expectedProvider"), expectedConversationId: text(payload, "expectedConversationId"),
    destinationRevision: whole(payload, "destinationRevision"),
    workspacePath: text(editor, "workspacePath"), expectedTitle: text(editor, "expectedTitle"),
    viewColumn: whole(editor, "viewColumn"), index: whole(editor, "index"),
  };
  const { requestId, destinationId, expectedProvider, expectedConversationId, destinationRevision } = fields;
  const { workspacePath, expectedTitle, viewColumn, index } = fields;
  if (
    requestId === null || destinationId === null || expectedProvider === null || expectedConversationId === null ||
    destinationRevision === null || workspacePath === null || expectedTitle === null || viewColumn === null || index === null
  ) return null;
  return {
    requestId, destinationId, destinationRevision, expectedProvider, expectedConversationId,
    editor: { workspacePath, viewColumn, index, expectedTitle },
  };
}

export interface ConnectionIdentity {
  connectorId: string;
  epoch: string;
}

/** Registry frames are untrusted input too: shape, version, and the bound connector and epoch are checked. */
export function parseRegistryMessage(raw: unknown, identity: ConnectionIdentity): RegistryMessage | null {
  if (!isRecord(raw) || text(raw, "protocolVersion") !== PROTOCOL_VERSION) return null;
  const type = text(raw, "type");
  const payload = raw["payload"];
  if (type === "error" && isRecord(payload)) {
    const code = text(payload, "code");
    const message = text(payload, "message");
    return code !== null && message !== null ? { kind: "error", code, message } : null;
  }
  const connectorId = text(raw, "connectorId");
  if (connectorId !== identity.connectorId || connectorId === UNBOUND_CONNECTOR_ID) return null;
  if (text(raw, "connectionEpoch") !== identity.epoch) return null;
  switch (type) {
    case "hello.ack": return { kind: "helloAck" };
    case "snapshot.request": return { kind: "snapshotRequest" };
    case "activate.request": {
      const request = parseRequest(payload);
      return request === null ? null : { kind: "activateRequest", request };
    }
    default: return null;
  }
}
