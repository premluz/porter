import { chatgptAdapter } from "./chatgpt.js";
import { claudeAdapter } from "./claude.js";
import type { ConversationMatch, ProviderAdapter } from "./types.js";

/** Every provider Porter can recognise. Adding one is adding an entry here, plus tests. */
export const ADAPTERS: readonly ProviderAdapter[] = [claudeAdapter, chatgptAdapter];

export function adapterForProvider(provider: string): ProviderAdapter | undefined {
  return ADAPTERS.find((adapter) => adapter.provider === provider);
}

/** First adapter whose rules accept the URL. Rules are exact, so two adapters never both match. */
export function recognise(
  rawUrl: string | undefined,
): { adapter: ProviderAdapter; match: ConversationMatch } | null {
  for (const adapter of ADAPTERS) {
    const match = adapter.match(rawUrl);
    if (match !== null) return { adapter, match };
  }
  return null;
}

export const ADAPTER_VERSIONS: Record<string, string> = Object.fromEntries(
  ADAPTERS.map((adapter) => [adapter.provider, adapter.adapterVersion]),
);
