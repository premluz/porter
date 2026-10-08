import { parseRegistryMessage, type ConnectionIdentity } from "./guards.js";
import { ADAPTER_VERSIONS } from "./inventory.js";
import {
  connectorIdFor, PROTOCOL_VERSION,
  type ActivateRequest, type ActivationResultPayload, type OutboundMessage, type TabReport,
} from "./protocol.js";

export interface PortEvent<Listener> {
  addListener(listener: Listener): void;
}

export interface NativePort {
  postMessage(message: unknown): void;
  disconnect(): void;
  onMessage: PortEvent<(message: unknown) => void>;
  onDisconnect: PortEvent<() => void>;
}

export interface Settings {
  installationId: string;
  profileAlias?: string | undefined;
}

export type ConnectionState = "idle" | "connecting" | "connected" | "unavailable" | "disconnected";

export interface BridgeStatus {
  state: ConnectionState;
  detail: string | null;
  trackedTabs: number;
}

export interface BridgeDeps {
  connect(): NativePort;
  /** The browser's reason for the last disconnect, if it gave one. */
  disconnectReason(): string | undefined;
  loadSettings(): Promise<Settings>;
  collectTabs(): Promise<TabReport[]>;
  activate(request: ActivateRequest): Promise<ActivationResultPayload>;
  randomId(): string;
  now(): Date;
  schedule(callback: () => void, delayMs: number): void;
  log(message: string, detail?: unknown): void;
}

export const HEARTBEAT_INTERVAL_MS = 30_000;
export const DUPLICATE_RETRY_DELAY_MS = 1_000;
const MAX_DUPLICATE_RETRIES = 5;

/**
 * One native-messaging connection. Every connection is a new epoch with sequence 0, and nothing
 * is replayed across epochs: after a reconnect the snapshot is rebuilt from the live tabs.
 */
export class BridgeClient {
  private port: NativePort | null = null;
  private identity: ConnectionIdentity | null = null;
  private sequence = 0;
  private opening = false;
  private duplicateRetries = 0;
  private lastRegistryError: string | null = null;
  private current: BridgeStatus = { state: "idle", detail: null, trackedTabs: 0 };

  constructor(private readonly deps: BridgeDeps) {}

  status(): BridgeStatus {
    return { ...this.current };
  }

  async ensureConnected(): Promise<void> {
    if (this.port !== null || this.opening) return;
    this.opening = true;
    try {
      this.open(await this.deps.loadSettings());
    } finally {
      this.opening = false;
    }
  }

  disconnect(): void {
    const port = this.port;
    this.port = null;
    this.identity = null;
    this.current = { state: "idle", detail: null, trackedTabs: 0 };
    port?.disconnect();
  }

  async sendSnapshot(): Promise<void> {
    if (this.current.state !== "connected") return;
    const tabs = await this.deps.collectTabs();
    this.current.trackedTabs = tabs.length;
    this.send({ type: "inventory.snapshot", payload: { tabs } });
  }

  private open(settings: Settings): void {
    const port = this.deps.connect();
    const identity = { connectorId: connectorIdFor(settings.installationId), epoch: this.deps.randomId() };
    this.port = port;
    this.identity = identity;
    this.sequence = 0;
    this.lastRegistryError = null;
    this.current = { state: "connecting", detail: null, trackedTabs: 0 };
    port.onMessage.addListener((raw) => void this.receive(port, raw));
    port.onDisconnect.addListener(() => this.closed(port));
    const payload = {
      installationId: settings.installationId,
      adapterVersions: ADAPTER_VERSIONS,
      ...(settings.profileAlias === undefined ? {} : { profileAlias: settings.profileAlias }),
    };
    this.send({ type: "hello", payload });
  }

  private send(message: OutboundMessage): void {
    if (this.port === null || this.identity === null) return;
    this.port.postMessage({
      protocolVersion: PROTOCOL_VERSION,
      messageId: this.deps.randomId(),
      connectorId: this.identity.connectorId,
      connectionEpoch: this.identity.epoch,
      sequence: this.sequence++,
      type: message.type,
      sentAt: this.deps.now().toISOString(),
      payload: message.payload,
    });
  }

  private async receive(port: NativePort, raw: unknown): Promise<void> {
    if (port !== this.port || this.identity === null) return;
    const message = parseRegistryMessage(raw, this.identity);
    if (message === null) {
      this.deps.log("ignored an unrecognized registry message");
      return;
    }
    switch (message.kind) {
      case "helloAck":
        this.current.state = "connected";
        this.duplicateRetries = 0;
        this.scheduleHeartbeat(port);
        return this.sendSnapshot();
      case "snapshotRequest":
        return this.sendSnapshot();
      case "activateRequest":
        return this.send({ type: "activate.result", payload: await this.deps.activate(message.request) });
      case "error":
        this.lastRegistryError = message.code;
        this.current.detail = `${message.code}: ${message.message}`;
    }
  }

  private closed(port: NativePort): void {
    if (port !== this.port) return;
    const wasConnected = this.current.state === "connected";
    this.port = null;
    this.identity = null;
    const reason = this.deps.disconnectReason();
    this.current = {
      state: wasConnected ? "disconnected" : "unavailable",
      detail: reason ?? this.current.detail,
      trackedTabs: 0,
    };
    this.deps.log("native port closed", this.current.detail);
    if (this.lastRegistryError === "duplicateInstallation" && this.duplicateRetries < MAX_DUPLICATE_RETRIES) {
      // The previous connection can still be closing on the registry side; a short retry resolves it.
      this.duplicateRetries += 1;
      this.deps.schedule(() => void this.ensureConnected(), DUPLICATE_RETRY_DELAY_MS);
    }
  }

  private scheduleHeartbeat(port: NativePort): void {
    this.deps.schedule(() => {
      if (port !== this.port) return;
      this.send({ type: "heartbeat", payload: {} });
      this.scheduleHeartbeat(port);
    }, HEARTBEAT_INTERVAL_MS);
  }
}
