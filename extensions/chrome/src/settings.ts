import type { Settings } from "./bridge.js";

const INSTALLATION_ID_KEY = "installationId";
const PROFILE_ALIAS_KEY = "profileAlias";

/**
 * Chrome never tells an extension which profile it runs in, so each profile identifies itself
 * with a random installation ID plus an alias the user types. The alias is a label, not proof.
 */
export async function loadSettings(): Promise<Settings> {
  const stored = await chrome.storage.local.get([INSTALLATION_ID_KEY, PROFILE_ALIAS_KEY]);
  const existing: unknown = stored[INSTALLATION_ID_KEY];
  const installationId = typeof existing === "string" && existing !== "" ? existing : crypto.randomUUID();
  if (installationId !== existing) await chrome.storage.local.set({ [INSTALLATION_ID_KEY]: installationId });
  const alias: unknown = stored[PROFILE_ALIAS_KEY];
  const trimmed = typeof alias === "string" ? alias.trim() : "";
  return trimmed === "" ? { installationId } : { installationId, profileAlias: trimmed };
}

export async function saveAlias(alias: string): Promise<void> {
  await chrome.storage.local.set({ [PROFILE_ALIAS_KEY]: alias.trim() });
}

export function isAliasChange(changes: Record<string, unknown>): boolean {
  return PROFILE_ALIAS_KEY in changes;
}
