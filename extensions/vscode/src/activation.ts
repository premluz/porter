import { conversationIdFor } from "./identity.js";
import type { ActivateRequest, ActivationOutcome, ActivationResultPayload } from "./protocol.js";
import { commandsFor, findConversationTabs, judge, type EditorTab, type GroupLike } from "./tabs.js";

export interface ActivationApi {
  /** This window's tab groups as they are right now. */
  groups(): GroupLike[];
  workspacePath(): string;
  runCommand(command: string): Promise<void>;
  settle(): Promise<void>;
  log(message: string): void;
}

function result(request: ActivateRequest, outcome: ActivationOutcome): ActivationResultPayload {
  return {
    requestId: request.requestId,
    destinationId: request.destinationId,
    destinationRevision: request.destinationRevision,
    outcome,
  };
}

/** Ordinal of a tab among same-titled Claude tabs, the same rule the snapshot uses. */
function ordinalOf(tabs: readonly EditorTab[], target: EditorTab): number {
  return tabs.filter((tab) => tab.provider === target.provider && tab.label === target.label).indexOf(target);
}

/**
 * Finds the tab the registry meant. The request names a position, a title, and an identity derived
 * from both; the tab is acted on only if all three still agree, so a tab that moved, was renamed,
 * or was replaced is refused rather than guessed at.
 */
function locate(request: ActivateRequest, tabs: readonly EditorTab[], workspacePath: string): EditorTab | ActivationOutcome {
  const { viewColumn, index, expectedTitle } = request.editor;
  const sameTitle = tabs.filter((tab) => tab.provider === request.expectedProvider && tab.label === expectedTitle);
  if (sameTitle.length === 0) return "targetGone";
  const atPosition = sameTitle.find((tab) => tab.viewColumn === viewColumn && tab.index === index);
  const candidate = atPosition ?? (sameTitle.length === 1 ? sameTitle[0] : undefined);
  if (candidate === undefined) return "targetChanged";
  const identity = conversationIdFor(workspacePath, candidate.provider, candidate.label, ordinalOf(tabs, candidate));
  return identity === request.expectedConversationId ? candidate : "targetChanged";
}

async function bringForward(target: EditorTab, api: ActivationApi): Promise<ActivationOutcome> {
  if (target.isActive) return "activated";
  const commands = commandsFor(target);
  if (commands === null) return "unsupported";
  await api.runCommand(commands.focusGroup);
  await api.runCommand(commands.openAtIndex);
  await api.settle();
  const after = findConversationTabs(api.groups()).find((tab) => tab.isActive);
  const verdict = judge(target, false, after, true);
  return verdict === "worked" ? "activated" : "failed";
}

export async function activate(request: ActivateRequest, api: ActivationApi): Promise<ActivationResultPayload> {
  try {
    if (request.editor.workspacePath !== api.workspacePath()) return result(request, "targetChanged");
    const found = locate(request, findConversationTabs(api.groups()), api.workspacePath());
    if (typeof found === "string") return result(request, found);
    return result(request, await bringForward(found, api));
  } catch (error) {
    api.log(`activation ${request.requestId} failed: ${String(error)}`);
    return result(request, "failed");
  }
}
