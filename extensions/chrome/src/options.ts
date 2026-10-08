import { ADAPTERS } from "./adapters/registry.js";
import type { ProviderAdapter } from "./adapters/types.js";
import type { BridgeStatus } from "./bridge.js";
import { STATUS_REQUEST } from "./protocol.js";
import { loadSettings, saveAlias } from "./settings.js";

const REFRESH_INTERVAL_MS = 2_000;

function element<T extends HTMLElement>(id: string, type: new () => T): T {
  const found = document.getElementById(id);
  if (!(found instanceof type)) throw new Error(`options.html is missing #${id}`);
  return found;
}

const aliasInput = element("alias", HTMLInputElement);
const saveButton = element("save-alias", HTMLButtonElement);
const providerList = element("providers", HTMLUListElement);
const connectionState = element("connection-state", HTMLParagraphElement);
const connectionDetail = element("connection-detail", HTMLParagraphElement);

const STATE_TEXT: Record<BridgeStatus["state"], string> = {
  idle: "Not connected yet",
  connecting: "Connecting to Porter…",
  connected: "Connected to Porter",
  unavailable: "Porter is not running or is not installed for this browser",
  disconnected: "Disconnected from Porter",
};

function isStatus(value: unknown): value is BridgeStatus {
  return typeof value === "object" && value !== null && "state" in value && "trackedTabs" in value;
}

async function providerRow(adapter: ProviderAdapter): Promise<HTMLLIElement> {
  const granted = await chrome.permissions.contains({ origins: [adapter.hostPermissionPattern] });
  const row = document.createElement("li");
  row.className = "provider";
  const label = document.createElement("span");
  label.textContent = `${adapter.displayName}: ${granted ? "access granted" : "no access"}`;
  if (!adapter.verified) {
    const badge = document.createElement("span");
    badge.className = "badge";
    badge.textContent = "untested";
    label.append(badge);
  }
  row.append(label);
  if (!granted) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = `Allow ${adapter.displayName}`;
    // request() must run inside the click handler to count as a user gesture.
    button.addEventListener("click", () => {
      void chrome.permissions.request({ origins: [adapter.hostPermissionPattern] }).then(refresh);
    });
    row.append(button);
  }
  return row;
}

async function refresh(): Promise<void> {
  providerList.replaceChildren(...(await Promise.all(ADAPTERS.map(providerRow))));
  const status: unknown = await chrome.runtime.sendMessage(STATUS_REQUEST);
  if (!isStatus(status)) {
    connectionState.textContent = "The extension is starting";
    return;
  }
  connectionState.textContent = STATE_TEXT[status.state];
  connectionDetail.textContent = status.state === "connected"
    ? `${status.trackedTabs} conversation tab(s) reported`
    : (status.detail ?? "");
}

saveButton.addEventListener("click", () => void saveAlias(aliasInput.value).then(refresh));
void loadSettings().then((settings) => {
  aliasInput.value = settings.profileAlias ?? "";
});
void refresh();
setInterval(() => void refresh(), REFRESH_INTERVAL_MS);
