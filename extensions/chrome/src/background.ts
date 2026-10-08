import { activate } from "./activation.js";
import { BridgeClient, type NativePort } from "./bridge.js";
import { buildReports, grantedPatterns, missingTabIds, urlShape } from "./inventory.js";
import { NATIVE_HOST_NAME, STATUS_REQUEST } from "./protocol.js";
import { isAliasChange, loadSettings } from "./settings.js";

const RECONNECT_ALARM = "porter-reconnect";
const RECONNECT_PERIOD_MINUTES = 0.5;
const SNAPSHOT_DEBOUNCE_MS = 250;

const NO_TAB_ERROR = /No tab with id/i;

let lastReportedTabIds = new Set<number>();

/**
 * A tab that vanishes from the list while still open changes its route in Porter. Say why, with
 * no chat identifiers, so the cause can be found from this console rather than guessed.
 */
async function explainDropouts(reports: Awaited<ReturnType<typeof buildReports>>): Promise<void> {
  for (const id of missingTabIds(lastReportedTabIds, reports)) {
    try {
      const tab = await chrome.tabs.get(id);
      console.warn(`[porter] tab ${id} left the list but still exists`, { status: tab.status, shape: urlShape(tab.url), title: tab.title === undefined ? "none" : "present" });
    } catch (error) {
      if (!(error instanceof Error && NO_TAB_ERROR.test(error.message))) console.warn(`[porter] could not look up tab ${id}`, error);
    }
  }
  lastReportedTabIds = new Set(reports.map((report) => report.tabId));
}

const client = new BridgeClient({
  connect: (): NativePort => chrome.runtime.connectNative(NATIVE_HOST_NAME),
  disconnectReason: () => chrome.runtime.lastError?.message,
  loadSettings,
  collectTabs: async () => {
    const patterns = grantedPatterns((await chrome.permissions.getAll()).origins);
    if (patterns.length === 0) return [];
    const reports = buildReports(await chrome.tabs.query({ url: patterns }));
    await explainDropouts(reports);
    return reports;
  },
  activate: (request) => activate(request, {
    getTab: async (tabId) => {
      try {
        return await chrome.tabs.get(tabId);
      } catch (error) {
        if (error instanceof Error && NO_TAB_ERROR.test(error.message)) return undefined;
        throw error;
      }
    },
    focusTab: async (tabId, windowId) => {
      await chrome.tabs.update(tabId, { active: true });
      await chrome.windows.update(windowId, { focused: true });
    },
    log: (message, error) => console.warn(`[porter] ${message}`, error),
  }),
  randomId: () => crypto.randomUUID(),
  now: () => new Date(),
  schedule: (callback, delayMs) => void setTimeout(callback, delayMs),
  log: (message, detail) => console.info(`[porter] ${message}`, detail ?? ""),
});

let snapshotTimer: ReturnType<typeof setTimeout> | undefined;

function scheduleSnapshot(): void {
  clearTimeout(snapshotTimer);
  snapshotTimer = setTimeout(() => void client.sendSnapshot(), SNAPSHOT_DEBOUNCE_MS);
}

function connect(): void {
  void client.ensureConnected();
}

chrome.runtime.onInstalled.addListener(connect);
chrome.runtime.onStartup.addListener(connect);
chrome.alarms.create(RECONNECT_ALARM, { periodInMinutes: RECONNECT_PERIOD_MINUTES });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === RECONNECT_ALARM) connect();
});

chrome.tabs.onUpdated.addListener(scheduleSnapshot);
chrome.tabs.onRemoved.addListener(scheduleSnapshot);
chrome.tabs.onAttached.addListener(scheduleSnapshot);
chrome.tabs.onReplaced.addListener(scheduleSnapshot);
chrome.permissions.onAdded.addListener(scheduleSnapshot);
chrome.permissions.onRemoved.addListener(scheduleSnapshot);

chrome.storage.onChanged.addListener((changes) => {
  if (!isAliasChange(changes)) return;
  client.disconnect();
  connect();
});

chrome.runtime.onMessage.addListener((message: unknown, sender, sendResponse) => {
  const fromOwnPage = sender.id === chrome.runtime.id;
  if (!fromOwnPage || message !== STATUS_REQUEST) return false;
  sendResponse(client.status());
  return false;
});

connect();
