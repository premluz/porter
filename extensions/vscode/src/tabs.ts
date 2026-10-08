/** Pure tab logic, with no `vscode` import, so it can be tested in plain Node. */

export const CLAUDE_VIEW_TYPE = "claudeVSCodePanel";
/** VS Code prefixes a webview panel's type with this when reporting it in the tab API. */
const WEBVIEW_PREFIX = "mainThreadWebview-";

export interface TabLike {
  label: string;
  isActive: boolean;
  /** The webview's view type, or undefined for any other kind of tab. */
  viewType: string | undefined;
}

export interface GroupLike {
  viewColumn: number;
  tabs: readonly TabLike[];
}

export interface ClaudeTab {
  viewColumn: number;
  /** Zero-based position within its editor group. */
  index: number;
  label: string;
  isActive: boolean;
}

export function isClaudeViewType(viewType: string | undefined): boolean {
  if (viewType === undefined) return false;
  const bare = viewType.startsWith(WEBVIEW_PREFIX) ? viewType.slice(WEBVIEW_PREFIX.length) : viewType;
  return bare === CLAUDE_VIEW_TYPE;
}

export function findClaudeTabs(groups: readonly GroupLike[]): ClaudeTab[] {
  return groups.flatMap((group) =>
    group.tabs.flatMap((tab, index) =>
      isClaudeViewType(tab.viewType)
        ? [{ viewColumn: group.viewColumn, index, label: tab.label, isActive: tab.isActive }]
        : [],
    ),
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

export function commandsFor(tab: ClaudeTab): PositionCommands | null {
  const word = GROUP_WORDS[tab.viewColumn - 1];
  if (word === undefined || tab.index + 1 > MAX_INDEX || tab.index < 0) return null;
  return {
    focusGroup: `workbench.action.focus${word}EditorGroup`,
    openAtIndex: `workbench.action.openEditorAtIndex${tab.index + 1}`,
  };
}

export type FocusVerdict = "worked" | "alreadyActive" | "didNotChange" | "wrongTab" | "unreachable";

/** Judges an attempt from what the tab API reports afterwards, never from the commands succeeding. */
export function judge(target: ClaudeTab, wasActive: boolean, afterActive: ClaudeTab | undefined, reachable: boolean): FocusVerdict {
  if (!reachable) return "unreachable";
  if (wasActive) return "alreadyActive";
  if (afterActive === undefined) return "didNotChange";
  const same = afterActive.viewColumn === target.viewColumn && afterActive.index === target.index;
  return same ? "worked" : "wrongTab";
}
