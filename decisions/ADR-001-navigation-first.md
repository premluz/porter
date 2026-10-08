---
id: "ADR-001"
type: "decision"
title: "Navigation-first product boundary"
status: "accepted"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/product", "area/security", "phase/r1"]
summary: "Records the user-selected shortcut-first product boundary."
related: ["DOC-CONSTITUTION", "DOC-SCOPE"]
---

# ADR-001 — Navigation-first product

- Date: 2026-10-08.
- Status: accepted product baseline from the user's expressed direction.
- Decider: Prem (product direction); assistant (documentation).

## Context

The original reference coordinates coding agents and routes questions/answers. The user narrowed the concept to a conversation shortcut utility that also includes ordinary active chats. Selecting an item returns to the original interface for decisions.

## Decision

R1 discovers or pins supported conversations, observes available status, and activates an exact destination. It does not send prompts or approvals. Phone synchronization is a later core milestone. Preview, composer, and summaries are separately scoped extensions.

## Consequences

A useful local product can ship without provider credentials, model calls, a new terminal runtime, or remote command relay. Metadata access and exact-destination correctness still matter. Desktop entries can be useful with only a manually pinned deep link and unknown status.

## Alternatives considered

Full agent orchestration would require control, delivery, permissions, and broad runtime integrations. A static link launcher is simpler but loses observed-tab identity and supported status. The selected scope combines navigation utility with incremental observation.

## Revisit when

The user explicitly makes composing or remote decisions a primary requirement. Supersede this ADR with an explicit capability and security model rather than silently expanding R1.
