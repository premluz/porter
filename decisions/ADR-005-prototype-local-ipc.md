---
id: "ADR-005"
type: "decision"
title: "Prototype local IPC: same-user Unix sockets"
status: "proposed"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/macos", "area/browser", "area/security", "phase/r1"]
summary: "Why the bridge prototype uses Unix domain sockets instead of the XPC service ADR-002 proposed, and what that does not yet protect."
related: ["ADR-002", "DOC-ARCHITECTURE", "DOC-SECURITY", "PLAN-001"]
---

# ADR-005 — Prototype local IPC

- Status: proposed; prototype implemented and tested with a simulated Chrome, not yet with real Chrome profiles.
- Date / owner: 2026-10-08; Prem approves.

## Context

ADR-002 proposed a signed native helper reaching the registry over XPC. Chrome starts the helper itself, outside any launchd job, so an XPC Mach service must be registered with launchd before the helper can reach it. That registration depends on the app packaging and signing work in TASK-027, which does not exist yet.

## Decision

For the TASK-011 prototype:

- `porter-native-host` (started by Chrome) relays length-prefixed frames to the registry over a Unix domain socket and interprets nothing.
- The socket lives in `~/Library/Application Support/Porter/`, a directory that must be mode 0700 and owned by the user, with the socket at mode 0600. Every accepted connection is checked with `getpeereid`; a different user is refused before any byte is read.
- Chrome-to-host frames are capped at 64 KiB (the application limit) even though Chrome allows 64 MiB, and the cap is applied before the body is read.
- The relay refuses to start unless the origin Chrome passes appears in `allowed-origins.txt`, written by the install script. A missing file fails closed.
- The registry does not trust a connector's claimed identity. A connector ID must equal `chrome-<installationId>`, only one live connection per installation is allowed, and every later message must carry the bound connector ID and epoch.
- No public localhost listener exists.

## What this does not protect

Any process running as the same user can connect to the socket and claim an installation ID that is not currently connected, because there is no code-signature check on the peer. This matches the browser's own trust boundary for a same-user attacker, but it is weaker than the signed-helper design. The registry also cannot tell that a connector's tab list is honest; it only constrains what a connector may report (declared providers, https chat URLs, bounded sizes).

## Alternatives

XPC with a launchd-registered Mach service and a code-signing requirement on the peer: stronger, needs the signed app and service packaging first. A localhost HTTP listener: rejected by the security document. Chrome-launched helper hosting the registry itself: breaks the single-writer rule across profiles.

## Evidence / validation needed

- Real two-profile run (TEST-001/002/011) in PLAN-001 step 2.
- Replace the peer check with a code-signing requirement when the signed helper exists (TASK-027), then supersede this ADR or accept it with that change.
- Measure whether `NSRunningApplication.activate()` from the registry process actually brings Chrome forward; the prototype reports its result but does not prove it.

## Consequences

The registry and the pane can share one `RegistryService`, so the Mac app embeds the same code the daemon runs today.

## Revisit trigger

Signed helper packaging, App Store sandbox constraints, or any second same-user client that needs the socket.

## Supersedes / superseded by

Refines the transport part of ADR-002; does not replace it.
