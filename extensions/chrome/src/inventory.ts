import { ADAPTERS, ADAPTER_VERSIONS, recognise } from "./adapters/registry.js";
import { MAX_TABS_PER_SNAPSHOT, type TabReport } from "./protocol.js";

export interface TabLike {
  id?: number | undefined;
  windowId?: number | undefined;
  url?: string | undefined;
  title?: string | undefined;
}

export { ADAPTER_VERSIONS };

/** Host patterns the user has actually granted. Without a grant Chrome hides tab URLs anyway. */
export function grantedPatterns(origins: readonly string[] | undefined): string[] {
  const granted = new Set(origins ?? []);
  return ADAPTERS.map((adapter) => adapter.hostPermissionPattern).filter((pattern) => granted.has(pattern));
}

/** Only tabs an adapter recognizes are ever reported; other browsing never leaves the browser. */
export function reportFor(tab: TabLike): TabReport | null {
  const recognised = recognise(tab.url);
  if (recognised === null || tab.id === undefined || tab.windowId === undefined) return null;
  return {
    tabId: tab.id,
    windowId: tab.windowId,
    provider: recognised.adapter.provider,
    providerConversationId: recognised.match.providerConversationId,
    title: recognised.adapter.cleanTitle(tab.title),
    canonicalUrl: recognised.match.canonicalUrl,
  };
}

const LONG_IDENTIFIER = /[A-Za-z0-9-]{16,}/g;

/** An address with identifiers blanked out, safe to log: enough to see why a tab stopped matching. */
export function urlShape(raw: string | undefined): string {
  if (raw === undefined) return "(no url visible)";
  try {
    const url = new URL(raw);
    return `${url.protocol}//${url.host}${url.pathname.replace(LONG_IDENTIFIER, "<id>")}`;
  } catch {
    return "(unparseable url)";
  }
}

/** Tabs reported last time that the latest list left out. */
export function missingTabIds(previous: ReadonlySet<number>, current: readonly TabReport[]): number[] {
  const now = new Set(current.map((report) => report.tabId));
  return [...previous].filter((id) => !now.has(id)).sort((a, b) => a - b);
}

export function buildReports(tabs: readonly TabLike[]): TabReport[] {
  return tabs
    .map(reportFor)
    .filter((report): report is TabReport => report !== null)
    .sort((a, b) => a.tabId - b.tabId)
    .slice(0, MAX_TABS_PER_SNAPSHOT);
}
