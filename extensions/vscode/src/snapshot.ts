import { conversationIdFor } from "./identity.js";
import { PROVIDER_RULES, type EditorTab } from "./tabs.js";
import type { RecencyTracker } from "./recency.js";

/** 0.2.0: reports when each tab was last the focused one. The app asks windows still on 0.1.0 to reload. */
export const ADAPTER_VERSION = "0.2.0";
/** Every provider this companion can recognise, declared to the registry in hello. */
export const ADAPTER_VERSIONS: Record<string, string> = Object.fromEntries(
  PROVIDER_RULES.map((rule) => [rule.provider, ADAPTER_VERSION]),
);
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
  /** When the tab last became the focused one, if known. Orders the list only. */
  lastActiveAt?: string;
}

interface Identified {
  tab: EditorTab;
  id: string;
  title: string;
}

/** Same-titled tabs of one provider are told apart by their order, the only difference an editor shows. */
function identify(workspacePath: string, tabs: readonly EditorTab[]): Identified[] {
  const seen = new Map<string, number>();
  return tabs.map((tab) => {
    const title = tab.label.slice(0, MAX_TITLE_LENGTH) || "Untitled conversation";
    const key = `${tab.provider}\0${title}`;
    const ordinal = seen.get(key) ?? 0;
    seen.set(key, ordinal + 1);
    return { tab, title, id: conversationIdFor(workspacePath, tab.provider, title, ordinal) };
  });
}

export function buildReports(
  workspacePath: string, tabs: readonly EditorTab[], recency: RecencyTracker, nowMs: number,
): EditorTabReport[] {
  const identified = identify(workspacePath, tabs);
  recency.observe(identified.map(({ id, tab }) => ({ id, active: tab.isActive })), nowMs);
  return identified.map(({ tab, id, title }) => {
    const used = recency.lastActive(id);
    const report: EditorTabReport = {
      provider: tab.provider, providerConversationId: id, title, workspacePath,
      viewColumn: tab.viewColumn, index: tab.index,
    };
    return used === undefined ? report : { ...report, lastActiveAt: new Date(used).toISOString() };
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
