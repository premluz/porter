import type { BridgeDeps, NativePort } from "../src/bridge.js";
import { BridgeClient } from "../src/bridge.js";
import type { TabReport } from "../src/protocol.js";

export const INSTALLATION_ID = "6f1c2a3e-4444-4a1a-8a1a-000000000001";
export const CONNECTOR_ID = `chrome-${INSTALLATION_ID}`;
export const TAB: TabReport = {
  tabId: 42, windowId: 7, provider: "claude", providerConversationId: "chat-a",
  title: "Release plan", canonicalUrl: "https://claude.ai/chat/chat-a",
};

export class FakePort implements NativePort {
  sent: Array<Record<string, unknown>> = [];
  disconnected = false;
  private messageListeners: Array<(m: unknown) => void> = [];
  private disconnectListeners: Array<() => void> = [];
  onMessage = { addListener: (l: (m: unknown) => void) => void this.messageListeners.push(l) };
  onDisconnect = { addListener: (l: () => void) => void this.disconnectListeners.push(l) };
  postMessage(message: unknown): void {
    this.sent.push(message as Record<string, unknown>);
  }
  disconnect(): void {
    this.disconnected = true;
  }
  receive(message: unknown): void {
    for (const listener of this.messageListeners) listener(message);
  }
  drop(): void {
    for (const listener of this.disconnectListeners) listener();
  }
  get types(): unknown[] {
    return this.sent.map((m) => m["type"]);
  }
}

export function setup(options: { alias?: string; tabs?: TabReport[] } = {}) {
  const ports: FakePort[] = [];
  const scheduled: Array<{ callback: () => void; delayMs: number }> = [];
  let counter = 0;
  let reason: string | undefined;
  const activations: string[] = [];
  const deps: BridgeDeps = {
    connect: () => {
      const port = new FakePort();
      ports.push(port);
      return port;
    },
    disconnectReason: () => reason,
    loadSettings: async () => ({
      installationId: INSTALLATION_ID,
      ...(options.alias === undefined ? {} : { profileAlias: options.alias }),
    }),
    collectTabs: async () => options.tabs ?? [TAB],
    activate: async (request) => {
      activations.push(request.requestId);
      return { requestId: request.requestId, destinationId: request.destinationId,
        destinationRevision: request.destinationRevision, outcome: "activated" };
    },
    randomId: () => `00000000-0000-4000-8000-${String(++counter).padStart(12, "0")}`,
    now: () => new Date("2026-10-08T07:00:00.000Z"),
    schedule: (callback, delayMs) => void scheduled.push({ callback, delayMs }),
    log: () => undefined,
  };
  return { client: new BridgeClient(deps), ports, scheduled, activations, setReason: (r: string) => (reason = r) };
}

export const registryFrame = (epoch: string, type: string, payload: unknown, connectorId = CONNECTOR_ID) => ({
  protocolVersion: "1.0", messageId: "m", connectorId, connectionEpoch: epoch, sequence: 0,
  type, sentAt: "2026-10-08T07:00:00Z", payload,
});
export const flush = () => new Promise((resolve) => setImmediate(resolve));

export async function connected(options: { alias?: string; tabs?: TabReport[] } = {}) {
  const ctx = setup(options);
  await ctx.client.ensureConnected();
  const port = ctx.ports[0]!;
  const epoch = port.sent[0]!["connectionEpoch"] as string;
  port.receive(registryFrame(epoch, "hello.ack", { accepted: true }));
  await flush();
  return { ...ctx, port, epoch };
}

