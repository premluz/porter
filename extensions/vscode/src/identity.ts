import { createHash } from "node:crypto";

const WINDOW_DOMAIN = "porter-vscode-window";
const CONVERSATION_DOMAIN = "porter-vscode-conversation";
const CONVERSATION_ID_LENGTH = 16;
const UUID_BYTES = 16;
const VERSION_BYTE = 6;
const VARIANT_BYTE = 8;

function digest(domain: string, ...parts: string[]): Buffer {
  return createHash("sha256").update([domain, ...parts].join("\0")).digest();
}

/**
 * One window per folder, so the folder decides the connection's identity. It survives a window
 * reload and a restart, which lets the registry keep its pins attached to the same window.
 */
export function installationIdFor(workspacePath: string): string {
  const bytes = digest(WINDOW_DOMAIN, workspacePath).subarray(0, UUID_BYTES);
  bytes[VERSION_BYTE] = ((bytes[VERSION_BYTE] ?? 0) & 0x0f) | 0x40;
  bytes[VARIANT_BYTE] = ((bytes[VARIANT_BYTE] ?? 0) & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function connectorIdFor(installationId: string): string {
  return `vscode-${installationId.toLowerCase()}`;
}

/**
 * An editor tab has no ID of its own, so a stable-enough one is built from where it lives and what
 * it is called: the folder, the provider, the title, and which of several same-titled tabs it is. Renaming a chat
 * therefore gives it a new identity, a limit recorded in FACT-020.
 */
export function conversationIdFor(workspacePath: string, provider: string, title: string, ordinal: number): string {
  return digest(CONVERSATION_DOMAIN, workspacePath, provider, title, String(ordinal)).toString("hex").slice(0, CONVERSATION_ID_LENGTH);
}
