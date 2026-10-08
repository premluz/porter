export interface ConversationMatch {
  providerConversationId: string;
  canonicalUrl: string;
}

/**
 * A provider's identity rules. Adapters read only the tab URL and title: no page content, and no
 * selectors, so a provider changing its page layout cannot change what is reported.
 */
export interface ProviderAdapter {
  provider: string;
  displayName: string;
  adapterVersion: string;
  /** Optional host permission requested only when the user turns this provider on. */
  hostPermissionPattern: string;
  /** False until a real page of this provider has been checked against these rules. */
  verified: boolean;
  match(rawUrl: string | undefined): ConversationMatch | null;
  cleanTitle(raw: string | undefined): string;
}
