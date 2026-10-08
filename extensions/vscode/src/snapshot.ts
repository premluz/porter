import { conversationIdFor } from "./identity.js";
import type { ClaudeTab } from "./tabs.js";

export const PROVIDER = "claude-code";
export const ADAPTER_VERSION = "0.1.0";
/** Registry limit per snapshot; the frame size limit usually binds first. */
export const MAX_TABS = 200;
/** Headroom under the registry's 64 KiB frame limit for the envelope around the tabs. */
export const MAX_PAYLOAD_BYTES = 56 * 1024;
const MAX_TITLE_LENGTH = 512;

export interface EditorTabReport {
  provider: string;
  providerConversationId: string;
  title: string;
  workspacePath: string;
  viewColumn: number;
  index: number;
}

/** Same-titled tabs are told apart by their order, which is the only difference an editor shows. */
export function buildReports(workspacePath: string, tabs: readonly ClaudeTab[]): EditorTabReport[] {
  const seen = new Map<string, number>();
  return tabs.map((tab) => {
    const title = tab.label.slice(0, MAX_TITLE_LENGTH) || "Untitled conversation";
    const ordinal = seen.get(title) ?? 0;
    seen.set(title, ordinal + 1);
    return {
      provider: PROVIDER,
      providerConversationId: conversationIdFor(workspacePath, title, ordinal),
      title,
      workspacePath,
      viewColumn: tab.viewColumn,
      index: tab.index,
    };
  });
}

export interface FittedSnapshot {
  tabs: EditorTabReport[];
  dropped: number;
}

/** Keeps the earliest tabs that fit, and says how many were left out instead of failing the lot. */
export function fitSnapshot(reports: readonly EditorTabReport[]): FittedSnapshot {
  const kept: EditorTabReport[] = [];
  let bytes = 0;
  for (const report of reports.slice(0, MAX_TABS)) {
    const size = Buffer.byteLength(JSON.stringify(report)) + 1;
    if (bytes + size > MAX_PAYLOAD_BYTES) break;
    kept.push(report);
    bytes += size;
  }
  return { tabs: kept, dropped: reports.length - kept.length };
}
