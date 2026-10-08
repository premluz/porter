import * as vscode from "vscode";
import {
  commandsFor, findClaudeTabs, judge, matchByLabel, parseLabelRequest,
  type ClaudeTab, type FocusVerdict, type GroupLike,
} from "./tabs.js";

const SETTLE_MS = 400;
const COUNTDOWN_SECONDS = 5;
const output = vscode.window.createOutputChannel("Porter probe");

function snapshot(): GroupLike[] {
  return vscode.window.tabGroups.all.map((group) => ({
    viewColumn: group.viewColumn,
    tabs: group.tabs.map((tab) => ({
      label: tab.label,
      isActive: tab.isActive && group.isActive,
      viewType: tab.input instanceof vscode.TabInputWebview ? tab.input.viewType : undefined,
    })),
  }));
}

function activeClaudeTab(tabs: readonly ClaudeTab[]): ClaudeTab | undefined {
  return tabs.find((tab) => tab.isActive);
}

function pause(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/** Lists what Porter would report for this window. Nothing is sent anywhere. */
function listTabs(): void {
  const tabs = findClaudeTabs(snapshot());
  output.appendLine(`--- ${new Date().toISOString()} window "${vscode.workspace.name ?? "(no folder)"}" focused=${vscode.window.state.focused}`);
  output.appendLine(`Claude Code tabs: ${tabs.length}`);
  for (const tab of tabs) {
    output.appendLine(`  group ${tab.viewColumn}, position ${tab.index + 1}, ${tab.isActive ? "ACTIVE" : "background"}: ${tab.label}`);
  }
  output.show(true);
}

/** Tries the position-based commands and judges the result from the tab API, not from the call. */
async function tryFocus(target: ClaudeTab): Promise<FocusVerdict> {
  const wasActive = target.isActive;
  const commands = commandsFor(target);
  if (commands !== null && !wasActive) {
    await vscode.commands.executeCommand(commands.focusGroup);
    await vscode.commands.executeCommand(commands.openAtIndex);
    await pause(SETTLE_MS);
  }
  const after = activeClaudeTab(findClaudeTabs(snapshot()));
  return judge(target, wasActive, after, commands !== null);
}

async function probeFocus(preset?: ClaudeTab): Promise<void> {
  const tabs = findClaudeTabs(snapshot());
  const target = preset ?? (await choose(tabs));
  if (target === undefined) return;
  void vscode.window.showInformationMessage(
    `Porter probe: switch to a DIFFERENT tab now. Trying "${target.label}" in ${COUNTDOWN_SECONDS} seconds.`,
  );
  await pause(COUNTDOWN_SECONDS * 1000);
  const fresh = findClaudeTabs(snapshot()).find((tab) => tab.viewColumn === target.viewColumn && tab.index === target.index && tab.label === target.label);
  if (fresh === undefined) {
    output.appendLine(`focus test: "${target.label}" is no longer at group ${target.viewColumn} position ${target.index + 1}`);
    return;
  }
  const verdict = await tryFocus(fresh);
  output.appendLine(`focus test: group ${fresh.viewColumn} position ${fresh.index + 1} "${fresh.label}" -> ${verdict}; window focused=${vscode.window.state.focused}`);
  output.show(true);
}

async function choose(tabs: readonly ClaudeTab[]): Promise<ClaudeTab | undefined> {
  if (tabs.length === 0) {
    void vscode.window.showWarningMessage("Porter probe: no Claude Code tabs open in this window.");
    return undefined;
  }
  const picked = await vscode.window.showQuickPick(
    tabs.map((tab) => ({ label: tab.label, description: `group ${tab.viewColumn}, position ${tab.index + 1}`, tab })),
    { placeHolder: "Which Claude Code tab should be brought forward?" },
  );
  return picked?.tab;
}

/** Entry point for `open "vscode://porter-dev.porter-vscode-probe/focus?label=..."`, the route Porter would use. */
class ProbeUriHandler implements vscode.UriHandler {
  async handleUri(uri: vscode.Uri): Promise<void> {
    output.appendLine(`link received in window "${vscode.workspace.name ?? "(no folder)"}": ${uri.path}`);
    if (uri.path !== "/focus") {
      output.appendLine("  ignored: only /focus is handled");
      return;
    }
    const request = parseLabelRequest(uri.query);
    if ("error" in request) {
      output.appendLine(`  refused: ${request.error}`);
      return;
    }
    const matches = matchByLabel(findClaudeTabs(snapshot()), request.label);
    if (matches.length !== 1) {
      output.appendLine(`  not opened: ${matches.length} tabs here are titled "${request.label}"`);
      return;
    }
    const verdict = await tryFocus(matches[0] as ClaudeTab);
    output.appendLine(`  ${verdict}; window focused=${vscode.window.state.focused}`);
  }
}

export function activate(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    output,
    vscode.commands.registerCommand("porter.probeTabs", listTabs),
    vscode.commands.registerCommand("porter.probeFocus", () => probeFocus()),
    vscode.window.registerUriHandler(new ProbeUriHandler()),
  );
  output.appendLine("Porter probe active. Commands: 'Porter: List Claude Code tabs', 'Porter: Test bringing a Claude Code tab forward'.");
}

export function deactivate(): void {}
