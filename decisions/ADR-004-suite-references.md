---
id: "ADR-004"
type: "decision"
title: "Suite reference contract for Manager, Atlas, and Memento"
status: "proposed"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/product", "area/identity", "area/security", "phase/r1"]
summary: "How Porter links to sibling-product records without becoming their source of truth."
related: ["DOC-DATA", "DOC-CONSTITUTION", "ADR-001"]
---

# ADR-004 — Suite reference contract

- Status: proposed; schema and Swift model implemented, no cross-product exchange tested.
- Date / owner: 2026-10-08; Prem approves.

## Context

Porter is one of four sibling products (FACT-011). Manager owns projects, tasks and timelines. Atlas owns visual captures. Memento owns project memory and source-linked context. A Porter conversation, a Manager task, an Atlas capture and a Memento source must be linkable without any product copying another's records.

## Decision

- A `SuiteReference` carries only `contract` (`suite-ref/1`), a namespaced `type` (`porter.conversation`, `manager.task`, `atlas.capture`, `memento.source`, …), an opaque `id`, and optional `workspaceId`, `revision` and display `label`. No content fields exist; the schema rejects extras.
- A `ContextLink` joins two references with a `relation` (`relatesTo`, `capturedFor`, `citesSource`) and `origin: userLinked`. Inferred links need a new, reviewed origin value.
- Porter treats foreign IDs as opaque strings. It never derives meaning from their shape and never resolves them except through the owning product.
- Conversation activity status stays in Porter; project-task status stays in Manager. Neither field appears in the other's contract.
- A context packet that Memento assembles for handoff is shown for user review before Porter opens the chosen destination. Porter does not send it in R1.
- Implemented 2026-10-08 (`context-packet.schema.json`, `ContextPacket`, `PacketReview`): a packet holds references and short cited excerpts, is refused if it carries any field the contract does not name, starts with only current sources included, is capped at 16,000 characters when copied, is held in memory only, and is copied to the clipboard only on a user action. A destination is pre-selected only when exactly one open chat matches; several matches or several tabs are left for the user to choose.

Implemented in `packages/contracts/schemas/context-link.schema.json` and `packages/ConversationCore/Sources/ConversationCore/ContextLink.swift`.

## Alternatives and tradeoffs

A shared database across products would make joins easy but blur ownership, and it would push Porter toward being Manager's source of truth. URL-only links are easy to make but break across devices and leak structure. Opaque typed references with optional revisions keep ownership clear, at the cost of resolving each reference through its owner.

## Evidence / validation needed

- Confirm the ID formats Manager and Atlas actually use. Memento project and source IDs observed through its MCP on 2026-10-08 are UUIDs.
- Prove one round trip: an Atlas capture is linked to a Manager task, a Memento preview is reviewed, and Porter opens the selected destination.
- Decide where links are stored. The default is the product where the user created the link.

## Consequences

Any product can display a link it does not own as a labelled, unresolved reference. A deleted foreign record shows as a dangling reference rather than silently disappearing.

## Revisit trigger

Agent-suggested links, cross-account sharing, or a second reference contract version.

## Supersedes / superseded by

None.
