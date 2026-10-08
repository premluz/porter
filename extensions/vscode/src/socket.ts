import { connect } from "node:net";
import { homedir } from "node:os";
import { join } from "node:path";
import { FrameDecoder, FrameTooLarge, encodeFrame } from "./protocol.js";
import type { Transport } from "./client.js";

const SUPPORT_DIRECTORY_VARIABLE = "PORTER_SUPPORT_DIR";
const SOCKET_NAME = "bridge.sock";

/** Same location rules as the Mac side, so a development override reaches both. */
export function bridgeSocketPath(environment: NodeJS.ProcessEnv): string {
  const override = environment[SUPPORT_DIRECTORY_VARIABLE];
  const directory = override !== undefined && override !== "" ? override : join(homedir(), "Library", "Application Support", "Porter");
  return join(directory, SOCKET_NAME);
}

/** A framed connection to the registry's local socket. Failure to connect is a normal, retried state. */
export function connectToRegistry(path: string): Transport {
  const socket = connect(path);
  const decoder = new FrameDecoder();
  let closeReason: string | undefined;
  const closeCallbacks: Array<(reason: string | undefined) => void> = [];
  const messageCallbacks: Array<(message: unknown) => void> = [];
  let closed = false;

  const finish = (reason: string | undefined): void => {
    if (closed) return;
    closed = true;
    for (const callback of closeCallbacks) callback(reason ?? closeReason);
  };

  socket.on("data", (chunk: Buffer) => {
    try {
      for (const frame of decoder.push(chunk)) {
        const parsed: unknown = JSON.parse(frame.toString("utf8"));
        for (const callback of messageCallbacks) callback(parsed);
      }
    } catch (error) {
      closeReason = error instanceof FrameTooLarge ? "registry sent an oversized frame" : "registry sent unreadable data";
      socket.destroy();
    }
  });
  socket.on("error", (error: NodeJS.ErrnoException) => {
    closeReason = error.code === "ENOENT" || error.code === "ECONNREFUSED" ? "Porter is not running" : String(error.message);
  });
  socket.on("close", () => finish(undefined));

  return {
    send: (message) => void socket.write(encodeFrame(message)),
    close: () => socket.destroy(),
    onMessage: (callback) => void messageCallbacks.push(callback),
    onClose: (callback) => void closeCallbacks.push(callback),
  };
}
