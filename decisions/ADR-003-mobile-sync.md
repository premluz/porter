---
id: "ADR-003"
type: "decision"
title: "Metadata-only iPhone sync proposal"
status: "proposed"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/ios", "area/sync", "area/security", "phase/r2"]
summary: "Proposed simple iPhone companion and unresolved transport constraints."
related: ["DOC-ARCHITECTURE", "DOC-SECURITY", "DOC-QUESTIONS"]
---

# ADR-003 — Metadata-only iPhone synchronization

- Date: 2026-10-08.
- Status: proposed; do not treat transport behavior as verified.
- Owner: future mobile implementer.

## Context

The user wants phone access, while the first useful product is local Mac navigation. Phone cannot inherit desktop tab locators or account sessions. Syncing metadata is materially simpler than remotely sending agent commands.

## Decision proposal

Assume an iPhone companion, subject to platform confirmation. Evaluate CloudKit private-database metadata synchronization for devices using the same Apple account, with explicit app-level enrollment and data selection. R2 supports foreground refresh and last-observed state. Use supported mobile links and mark other entries Mac-only.

## Consequences

No custom remote-command backend is required for R2 if this transport proves sufficient. Sync sign-in and provider sign-in remain different. Background updates may be delayed; no continuous background socket or immediate status guarantee is assumed. Cloud provider access, record encryption, key handling, and revocation limits must be verified before privacy claims.

## Alternatives

A custom authenticated relay offers more transport control and can later carry explicit composer intents, but adds hosting, pairing, abuse prevention, operational monitoring, and a larger action surface. A browser-only phone view still needs a secure way to synchronize Mac state. Manual link export is a reduced fallback with no live status.

## Acceptance experiment

TASK-030 proves same-account enrollment, first sync, foreground convergence, Mac sleep, sign-out, offline cache, deletion/tombstones, and revocation semantics on a physical iPhone. Document what a previously enrolled device can retain or continue accessing. If required device isolation cannot be achieved, choose application-level encryption or another transport through a superseding ADR.

## Revisit when

Different cloud accounts, Android, near-real-time remote messages, remote machine control, or stronger device-key isolation becomes a requirement.
