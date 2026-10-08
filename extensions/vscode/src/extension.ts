import { randomUUID } from "node:crypto";
import { basename } from "node:path";
import * as vscode from "vscode";
import { activate as activateTab, type ActivationApi } from "./activation.js";
import { EditorClient, type ClientStatus } from "./client.js";
import { connectorIdFor, installationIdFor } from "./identity.js";
import { bridgeSocketPath, connectToRegistry } from "./socket.js";
import { buildReports } from "./snapshot.js";
import { findClaudeTabs, type GroupLike } from "./tabs.js";

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

function groupsNow(): GroupLike[] {
  return vscode.window.tabGroups.all.map((group) => ({
    viewColumn: group.viewColumn,
    tabs: group.tabs.map((tab) => ({
      label: tab.label,
      isActive: tab.isActive && group.isActive,
      viewType: tab.input instanceof vscode.TabInputWebview ? tab.input.viewType : undefined,
    })),
  }));
}

function pause(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function activate(context: vscode.ExtensionContext): void {
  const output = vscode.window.createOutputChannel("Porter");
  const statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 0);
  let client: EditorClient | null = null;
  let timer: ReturnType<typeof setTimeout> | undefined;

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
      reports: () => buildReports(workspace.path, findClaudeTabs(groupsNow())),
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
    vscode.commands.registerCommand("porter.showStatus", () => output.show(true)),
    vscode.commands.registerCommand("porter.listTabs", () => {
      const tabs = findClaudeTabs(groupsNow());
      output.appendLine(`Claude Code tabs here: ${tabs.length}`);
      for (const tab of tabs) output.appendLine(`  group ${tab.viewColumn}, position ${tab.index + 1}${tab.isActive ? " (active)" : ""}: ${tab.label}`);
      output.show(true);
    }),
    { dispose: () => client?.stop() },
  );
  begin();
}

export function deactivate(): void {}
