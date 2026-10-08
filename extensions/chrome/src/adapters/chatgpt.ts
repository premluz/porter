import { MAX_TITLE_LENGTH } from "../protocol.js";
import type { ConversationMatch, ProviderAdapter } from "./types.js";

const PROVIDER = "chatgpt";
const HOST_PERMISSION_PATTERN = "https://chatgpt.com/*";
const ORIGIN_HOST = "chatgpt.com";
const CHAT_PATH = /^\/c\/([A-Za-z0-9-]{1,128})$/;
const TITLE_SUFFIX = /\s+[-|–]\s+ChatGPT$/;
const UNTITLED = "Untitled conversation";

/**
 * UNVERIFIED: the /c/<id> shape is the one chatgpt.com has used, but it has not been checked
 * against a live page for this project. Until it is, the adapter is off unless the user grants
 * access, and the options page labels it as untested.
 */
function match(rawUrl: string | undefined): ConversationMatch | null {
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
  return { providerConversationId: id, canonicalUrl: `https://${ORIGIN_HOST}/c/${id}` };
}

function cleanTitle(raw: string | undefined): string {
  const stripped = (raw ?? "").replace(TITLE_SUFFIX, "").trim();
  if (stripped === "" || stripped === "ChatGPT") return UNTITLED;
  return stripped.slice(0, MAX_TITLE_LENGTH);
}

export const chatgptAdapter: ProviderAdapter = {
  provider: PROVIDER,
  displayName: "ChatGPT",
  adapterVersion: "0.1.0",
  hostPermissionPattern: HOST_PERMISSION_PATTERN,
  verified: false,
  match,
  cleanTitle,
};
