// Mirrors packages/contracts/schemas (envelope, bridge-payload, activation-result).
export const PROTOCOL_VERSION = "1.0";
export const NATIVE_HOST_NAME = "com.porter.bridge";
export const MAX_TITLE_LENGTH = 512;
export const MAX_TABS_PER_SNAPSHOT = 200;
export const UNBOUND_CONNECTOR_ID = "unbound";
export const STATUS_REQUEST = "porter.status";

export interface TabReport {
  tabId: number;
  windowId: number;
  provider: string;
  providerConversationId: string;
  title: string;
  canonicalUrl: string;
}

export type ActivationOutcome =
  | "activated"
  | "targetGone"
  | "targetChanged"
  | "permissionDenied"
  | "failed";

export interface ActivateRequest {
  requestId: string;
  destinationId: string;
  destinationRevision: number;
  tabId: number;
  windowId: number;
  expectedProvider: string;
  expectedConversationId: string;
}

export interface ActivationResultPayload {
  requestId: string;
  destinationId: string;
  destinationRevision: number;
  outcome: ActivationOutcome;
}

export interface HelloPayload {
  installationId: string;
  profileAlias?: string;
  adapterVersions: Record<string, string>;
}

export type OutboundMessage =
  | { type: "hello"; payload: HelloPayload }
  | { type: "inventory.snapshot"; payload: { tabs: TabReport[] } }
  | { type: "heartbeat"; payload: Record<string, never> }
  | { type: "activate.result"; payload: ActivationResultPayload };

export type RegistryMessage =
  | { kind: "helloAck" }
  | { kind: "snapshotRequest" }
  | { kind: "activateRequest"; request: ActivateRequest }
  | { kind: "error"; code: string; message: string };

export function connectorIdFor(installationId: string): string {
  return `chrome-${installationId.toLowerCase()}`;
}
