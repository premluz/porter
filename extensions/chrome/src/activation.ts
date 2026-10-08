import { adapterForProvider } from "./adapters/registry.js";
import type { TabLike } from "./inventory.js";
import type { ActivateRequest, ActivationOutcome, ActivationResultPayload } from "./protocol.js";

export interface ActivationApi {
  /** Resolves undefined when the tab no longer exists; any other failure rejects. */
  getTab(tabId: number): Promise<TabLike | undefined>;
  focusTab(tabId: number, windowId: number): Promise<void>;
}

export interface ActivationDeps extends ActivationApi {
  log(message: string, error: unknown): void;
}

function result(request: ActivateRequest, outcome: ActivationOutcome): ActivationResultPayload {
  return {
    requestId: request.requestId,
    destinationId: request.destinationId,
    destinationRevision: request.destinationRevision,
    outcome,
  };
}

/**
 * Re-verifies the target at the moment of the click, so a tab that was closed, navigated or
 * reused for another chat is refused instead of focused. The window used is the tab's current
 * one, not the registry's hint, which survives a tab being dragged to another window.
 */
export async function activate(
  request: ActivateRequest,
  deps: ActivationDeps,
): Promise<ActivationResultPayload> {
  try {
    const tab = await deps.getTab(request.tabId);
    if (tab === undefined) return result(request, "targetGone");
    if (tab.url === undefined) return result(request, "permissionDenied");
    // The provider comes from the request, so a tab can only be focused if it still shows that
    // provider's chat; an unknown provider can never match.
    const match = adapterForProvider(request.expectedProvider)?.match(tab.url) ?? null;
    if (match === null || match.providerConversationId !== request.expectedConversationId) {
      return result(request, "targetChanged");
    }
    if (tab.windowId === undefined) return result(request, "failed");
    await deps.focusTab(request.tabId, tab.windowId);
    return result(request, "activated");
  } catch (error) {
    deps.log(`activation ${request.requestId} failed`, error);
    return result(request, "failed");
  }
}
