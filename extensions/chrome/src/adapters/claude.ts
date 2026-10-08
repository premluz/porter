import { MAX_TITLE_LENGTH } from "../protocol.js";
import type { ConversationMatch, ProviderAdapter } from "./types.js";

export const PROVIDER = "claude";
export const ADAPTER_VERSION = "0.1.0";
export const HOST_PERMISSION_PATTERN = "https://claude.ai/*";

const ORIGIN_HOST = "claude.ai";
const CHAT_PATH = /^\/chat\/([A-Za-z0-9-]{1,128})$/;
const TITLE_SUFFIX = /\s+[-|–]\s+Claude$/;
const UNTITLED = "Untitled conversation";

export type { ConversationMatch };

/** Identity comes from the URL alone: no page content is read. Query and fragment are dropped. */
export function matchConversation(rawUrl: string | undefined): ConversationMatch | null {
  if (rawUrl === undefined) return null;
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    return null;
  }
  if (url.protocol !== "https:" || url.hostname !== ORIGIN_HOST || url.port !== "") return null;
  const id = CHAT_PATH.exec(url.pathname)?.[1];
  if (id === undefined) return null;
  return { providerConversationId: id, canonicalUrl: `https://${ORIGIN_HOST}/chat/${id}` };
}

/** Titles are display data only. The provider suffix format is unverified on live pages. */
export function cleanTitle(raw: string | undefined): string {
  const stripped = (raw ?? "").replace(TITLE_SUFFIX, "").trim();
  if (stripped === "" || stripped === "Claude") return UNTITLED;
  return stripped.slice(0, MAX_TITLE_LENGTH);
}

export const claudeAdapter: ProviderAdapter = {
  provider: PROVIDER,
  displayName: "Claude",
  adapterVersion: ADAPTER_VERSION,
  hostPermissionPattern: HOST_PERMISSION_PATTERN,
  verified: true,
  match: matchConversation,
  cleanTitle,
};
