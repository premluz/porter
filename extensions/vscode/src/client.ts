import { parseRegistryMessage, type ConnectionIdentity } from "./guards.js";
import {
  PROTOCOL_VERSION,
  type ActivateRequest, type ActivationResultPayload, type OutboundMessage,
} from "./protocol.js";
import { ADAPTER_VERSIONS, fitSnapshot, type EditorTabReport } from "./snapshot.js";

export interface Transport {
  send(message: unknown): void;
  close(): void;
  onMessage(callback: (message: unknown) => void): void;
  onClose(callback: (reason: string | undefined) => void): void;
}

export type ConnectionState = "idle" | "connecting" | "connected" | "unavailable";

export interface ClientStatus {
  state: ConnectionState;
  detail: string | null;
  reported: number;
  dropped: number;
}

export interface WindowIdentity {
  installationId: string;
  connectorId: string;
  folderName: string;
}

export interface ClientDeps {
  window: WindowIdentity;
  connect(): Transport;
  reports(): EditorTabReport[];
  activate(request: ActivateRequest): Promise<ActivationResultPayload>;
  randomId(): string;
  now(): Date;
  schedule(callback: () => void, delayMs: number): void;
  onStatus(status: ClientStatus): void;
}

export const HEARTBEAT_INTERVAL_MS = 30_000;
export const RETRY_DELAYS_MS = [1_000, 2_000, 5_000, 15_000, 30_000] as const;

/**
 * One window's connection to the registry. Every connection is a new epoch with sequence 0, and a
 * lost connection is retried with growing delays rather than assumed to stay up.
 */
export class EditorClient {
  private transport: Transport | null = null;
  private identity: ConnectionIdentity | null = null;
  private sequence = 0;
  private attempt = 0;
  private stopped = false;
  private current: ClientStatus = { state: "idle", detail: null, reported: 0, dropped: 0 };

  constructor(private readonly deps: ClientDeps) {}

  status(): ClientStatus {
    return { ...this.current };
  }

  start(): void {
    this.stopped = false;
    this.open();
  }

  stop(): void {
    this.stopped = true;
    this.transport?.close();
    this.transport = null;
    this.update({ state: "idle", detail: null });
  }

  /** Called when tabs change; a no-op until the registry has acknowledged this connection. */
  sendSnapshot(): void {
    if (this.current.state !== "connected") return;
    const fitted = fitSnapshot(this.deps.reports());
    this.update({ reported: fitted.tabs.length, dropped: fitted.dropped });
    this.send({ type: "inventory.snapshot", payload: { tabs: [], editorTabs: fitted.tabs } });
  }

  private open(): void {
    if (this.stopped || this.transport !== null) return;
    const transport = this.deps.connect();
    const identity = { connectorId: this.deps.window.connectorId, epoch: this.deps.randomId() };
    this.transport = transport;
    this.identity = identity;
    this.sequence = 0;
    this.update({ state: "connecting", detail: null });
    transport.onMessage((raw) => void this.receive(transport, raw));
    transport.onClose((reason) => this.closed(transport, reason));
    this.send({
      type: "hello",
      payload: {
        installationId: this.deps.window.installationId, profileAlias: this.deps.window.folderName,
        connectorKind: "vscode", adapterVersions: ADAPTER_VERSIONS,
      },
    });
  }

  private send(message: OutboundMessage): void {
    if (this.transport === null || this.identity === null) return;
    this.transport.send({
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

  private async receive(transport: Transport, raw: unknown): Promise<void> {
    if (transport !== this.transport || this.identity === null) return;
    const message = parseRegistryMessage(raw, this.identity);
    if (message === null) return;
    switch (message.kind) {
      case "helloAck":
        this.attempt = 0;
        this.update({ state: "connected", detail: null });
        this.scheduleHeartbeat(transport);
        return this.sendSnapshot();
      case "snapshotRequest":
        return this.sendSnapshot();
      case "activateRequest":
        return this.send({ type: "activate.result", payload: await this.deps.activate(message.request) });
      case "error":
        this.update({ detail: `${message.code}: ${message.message}` });
    }
  }

  private closed(transport: Transport, reason: string | undefined): void {
    if (transport !== this.transport) return;
    this.transport = null;
    this.identity = null;
    this.update({ state: "unavailable", detail: reason ?? this.current.detail, reported: 0, dropped: 0 });
    if (this.stopped) return;
    const delay = RETRY_DELAYS_MS[Math.min(this.attempt, RETRY_DELAYS_MS.length - 1)] ?? RETRY_DELAYS_MS[0];
    this.attempt += 1;
    this.deps.schedule(() => this.open(), delay);
  }

  private scheduleHeartbeat(transport: Transport): void {
    this.deps.schedule(() => {
      if (transport !== this.transport) return;
      this.send({ type: "heartbeat", payload: {} });
      this.scheduleHeartbeat(transport);
    }, HEARTBEAT_INTERVAL_MS);
  }

  private update(change: Partial<ClientStatus>): void {
    this.current = { ...this.current, ...change };
    this.deps.onStatus(this.status());
  }
}
