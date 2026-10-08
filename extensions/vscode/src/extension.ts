import { randomUUID } from "node:crypto";
import { basename } from "node:path";
import * as vscode from "vscode";
import { activate as activateTab, type ActivationApi } from "./activation.js";
import { EditorClient, type ClientStatus } from "./client.js";
import { connectorIdFor, installationIdFor } from "./identity.js";
import { bridgeSocketPath, connectToRegistry } from "./socket.js";
import { RecencyTracker } from "./recency.js";
import { buildReports } from "./snapshot.js";
import { findConversationTabs, type GroupLike } from "./tabs.js";

const SNAPSHOT_DEBOUNCE_MS = 250;
const SETTLE_MS = 400;

interface WindowWorkspace {
  /** A workspace file for multi-root windows, otherwise the single folder. Always a local path. */
  path: string;
  name: string;
}

/** Only local folders can be found again by the host, so remote and unsaved windows are not reported. */
function currentWorkspace(): WindowWorkspace | null {
  const file = vscode.workspace.workspaceFile;
  if (file !== undefined && file.scheme === "file") return { path: file.fsPath, name: vscode.workspace.name ?? basename(file.fsPath) };
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (folder === undefined || folder.uri.scheme !== "file") return null;
  return { path: folder.uri.fsPath, name: vscode.workspace.name ?? basename(folder.uri.fsPath) };
}

/** Webview panels and custom editors are the two kinds of tab a conversation can live in. */
function viewTypeOf(input: unknown): string | undefined {
  if (input instanceof vscode.TabInputWebview || input instanceof vscode.TabInputCustom) return input.viewType;
  return undefined;
}

function groupsNow(): GroupLike[] {
  return vscode.window.tabGroups.all.map((group) => ({
    viewColumn: group.viewColumn,
    tabs: group.tabs.map((tab) => ({
      label: tab.label,
      isActive: tab.isActive && group.isActive,
      viewType: viewTypeOf(tab.input),
    })),
  }));
}

function kindOf(input: unknown): string {
  const kinds: Array<[unknown, string]> = [
    [vscode.TabInputText, "text"], [vscode.TabInputTextDiff, "diff"], [vscode.TabInputCustom, "custom"],
    [vscode.TabInputWebview, "webview"], [vscode.TabInputNotebook, "notebook"], [vscode.TabInputTerminal, "terminal"],
  ];
  const found = kinds.find(([type]) => typeof type === "function" && input instanceof type);
  return found?.[1] ?? "other";
}

function pause(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel("Porter");
  const statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 0);
  let client: EditorClient | null = null;
  let timer: ReturnType<typeof setTimeout> | undefined;
  const recency = new RecencyTracker();

  const show = (status: ClientStatus): void => {
    const text = { idle: "off", connecting: "connecting…", connected: "connected", unavailable: "not connected" }[status.state];
    statusBar.text = `$(plug) Porter ${text}`;
    statusBar.tooltip = status.state === "connected"
      ? `Reporting ${status.reported} Claude Code tab(s)${status.dropped > 0 ? `; ${status.dropped} left out to fit` : ""}`
      : (status.detail ?? "Porter is not running");
    output.appendLine(`${new Date().toISOString()} ${status.state}${status.detail === null ? "" : ` (${status.detail})`}`);
  };

  const begin = (): void => {
    client?.stop();
    client = null;
    const workspace = currentWorkspace();
    if (workspace === null) {
      statusBar.text = "$(plug) Porter: no local folder";
      statusBar.tooltip = "Porter reports Claude Code tabs only for windows that have a local folder open.";
      statusBar.show();
      return;
    }
    const installationId = installationIdFor(workspace.path);
    const api: ActivationApi = {
      groups: groupsNow,
      workspacePath: () => workspace.path,
      runCommand: async (command) => void (await vscode.commands.executeCommand(command)),
      settle: () => pause(SETTLE_MS),
      log: (message) => output.appendLine(message),
    };
    client = new EditorClient({
      window: { installationId, connectorId: connectorIdFor(installationId), folderName: workspace.name },
      connect: () => connectToRegistry(bridgeSocketPath(process.env)),
      reports: () => buildReports(workspace.path, findConversationTabs(groupsNow()), recency, Date.now()),
      activate: (request) => activateTab(request, api),
      randomId: randomUUID,
      now: () => new Date(),
      schedule: (callback, delayMs) => void setTimeout(callback, delayMs),
      onStatus: show,
    });
    statusBar.show();
    client.start();
  };

  const scheduleSnapshot = (): void => {
    clearTimeout(timer);
    timer = setTimeout(() => client?.sendSnapshot(), SNAPSHOT_DEBOUNCE_MS);
  };

  context.subscriptions.push(
    output, statusBar,
    vscode.window.tabGroups.onDidChangeTabs(scheduleSnapshot),
    vscode.window.tabGroups.onDidChangeTabGroups(scheduleSnapshot),
    vscode.workspace.onDidChangeWorkspaceFolders(begin),
    // Coming back to a window uses its focused tab even though the tab did not change.
    vscode.window.onDidChangeWindowState((state) => {
      if (!state.focused) return;
      recency.touchActive(Date.now());
      scheduleSnapshot();
    }),
    vscode.commands.registerCommand("porter.showStatus", () => output.show(true)),
    vscode.commands.registerCommand("porter.listTabs", () => {
      const tabs = findConversationTabs(groupsNow());
      output.appendLine(`Conversation tabs here: ${tabs.length}`);
      for (const tab of tabs) output.appendLine(`  ${tab.provider}, group ${tab.viewColumn}, position ${tab.index + 1}${tab.isActive ? " (active)" : ""}: ${tab.label}`);
      output.show(true);
    }),
    // Shows what kind of tab everything in this window is, so a conversation Porter does not list can
    // be diagnosed from facts instead of guesses. Titles stay in this output panel.
    vscode.commands.registerCommand("porter.describeTabs", () => {
      output.appendLine("All tabs in this window (kind, view type, title):");
      for (const group of vscode.window.tabGroups.all) {
        group.tabs.forEach((tab, index) => {
          output.appendLine(`  group ${group.viewColumn}, position ${index + 1}: ${kindOf(tab.input)} ${viewTypeOf(tab.input) ?? "-"} | ${tab.label}`);
        });
      }
      output.show(true);
    }),
    { dispose: () => client?.stop() },
  );
  begin();
}

export function deactivate(): void {}
