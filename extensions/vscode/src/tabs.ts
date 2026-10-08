/** Pure tab logic, with no `vscode` import, so it can be tested in plain Node. */

/** VS Code prefixes a webview panel's type with this when reporting it in the tab API. */
const WEBVIEW_PREFIX = "mainThreadWebview-";

export interface ProviderRule {
  provider: string;
  /**
   * Tab view types, with or without the webview prefix. Taken from each extension's own manifest and
   * code: Claude Code registers a webview panel, and the OpenAI (Codex) extension a webview panel and
   * a custom editor for its conversations. The side-panel views of both are not editor tabs.
   */
  viewTypes: readonly string[];
}

export const PROVIDER_RULES: readonly ProviderRule[] = [
  { provider: "claude-code", viewTypes: ["claudeVSCodePanel"] },
  { provider: "codex", viewTypes: ["chatgpt.panelView", "chatgpt.conversationEditor"] },
];

export interface TabLike {
  label: string;
  isActive: boolean;
  /** The webview's or custom editor's view type, or undefined for any other kind of tab. */
  viewType: string | undefined;
}

export interface GroupLike {
  viewColumn: number;
  tabs: readonly TabLike[];
}

export interface EditorTab {
  provider: string;
  viewColumn: number;
  /** Zero-based position within its editor group. */
  index: number;
  label: string;
  isActive: boolean;
}

export function providerForViewType(viewType: string | undefined): string | undefined {
  if (viewType === undefined) return undefined;
  const bare = viewType.startsWith(WEBVIEW_PREFIX) ? viewType.slice(WEBVIEW_PREFIX.length) : viewType;
  return PROVIDER_RULES.find((rule) => rule.viewTypes.includes(bare))?.provider;
}

export function findConversationTabs(groups: readonly GroupLike[]): EditorTab[] {
  return groups.flatMap((group) =>
    group.tabs.flatMap((tab, index) => {
      const provider = providerForViewType(tab.viewType);
      return provider === undefined
        ? []
        : [{ provider, viewColumn: group.viewColumn, index, label: tab.label, isActive: tab.isActive }];
    }),
  );
}

/** The built-in commands that can reach a tab by position. Both only exist for small numbers. */
export const MAX_GROUP = 8;
export const MAX_INDEX = 9;
const GROUP_WORDS = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth"] as const;

export interface PositionCommands {
  focusGroup: string;
  openAtIndex: string;
}

export function commandsFor(tab: EditorTab): PositionCommands | null {
  const word = GROUP_WORDS[tab.viewColumn - 1];
  if (word === undefined || tab.index + 1 > MAX_INDEX || tab.index < 0) return null;
  return {
    focusGroup: `workbench.action.focus${word}EditorGroup`,
    openAtIndex: `workbench.action.openEditorAtIndex${tab.index + 1}`,
  };
}

export type FocusVerdict = "worked" | "alreadyActive" | "didNotChange" | "wrongTab" | "unreachable";

/** Judges an attempt from what the tab API reports afterwards, never from the commands succeeding. */
export function judge(target: EditorTab, wasActive: boolean, afterActive: EditorTab | undefined, reachable: boolean): FocusVerdict {
  if (!reachable) return "unreachable";
  if (wasActive) return "alreadyActive";
  if (afterActive === undefined) return "didNotChange";
  const same = afterActive.viewColumn === target.viewColumn && afterActive.index === target.index;
  return same ? "worked" : "wrongTab";
}
