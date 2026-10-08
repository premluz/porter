---
id: "DOC-PLAN"
type: "plan"
title: "Delivery roadmap"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/product", "area/quality", "phase/foundation", "phase/r0", "phase/r1", "phase/r2"]
summary: "Milestones, dependency order, and planning conventions."
related: ["DOC-TASKS", "PLAN-001", "DOC-SCOPE"]
---

# Delivery roadmap

## Outcome and constraints

Deliver a Mac conversation switcher with a compact glass edge pane, reliable exact-destination navigation, and honest status. Extend it with an iPhone metadata companion. Preview, composer, and summaries follow as separate capabilities. Requirements and acceptance are in docs/TECHNICAL_SCOPE.md and docs/VALIDATION_RELEASE.md.

This roadmap is the plan of work. TASKS.md is the canonical task-status ledger; PROGRESS.md records completed evidence. This file defines milestone gates rather than duplicating every changing task status.

## M0 — Project foundation

Outcome: a new agent can understand the project without previous chat history. The constitution, technical design, visual behavior, tasks, and memory model are explicit. Deliver the Markdown pack and working local documentation utility. Acceptance: documentation check passes and a retrieval walkthrough locates state, risks, identity rules, and the next plan. TASK-001 and TASK-002.

## M1 — Feasibility on a Mac

Outcome: demonstrate that the chosen integration and visual approach work on the user's actual platform before building the full interface. Tasks TASK-010 through TASK-014. Execute [PLAN-001](plans/PLAN-001-feasibility.md).

Prove a browser extension in two profiles can report its own tabs, send metadata through the native helper, and activate the selected existing tab/window. Test a supported desktop deep link and status observation in a real page. Prototype the capsule morph using native glass, including interruption and accessibility fallback. Record exact tested versions and unavailable capabilities. Gate: no unresolved destination-identity flaw; fallback behavior for unsupported desktop status agreed in the scope.

## M2 — Mac vertical slice

Outcome: a real supported conversation appears in the pane and a click returns to it. Implement shared core and database migrations, extension discovery, registry reduction, pane UI, native destination activation, pin/recent persistence. TASK-020 through TASK-024.

Order: contracts/core before consumers; bridge before real discovery; UI may use clearly labelled fixtures before bridge integration; end-to-end acceptance uses real tabs. After one provider works, add the second through the same adapter boundary. Gate: TEST-001 through TEST-007 and relevant keyboard tests pass on the reference Mac.

## M3 — Mac personal beta and distribution

Outcome: the utility survives normal daily use, restarts, and permission changes. TASK-025 through TASK-029. Add diagnostics, source management, retention, accessible motion, multi-display behavior, installer/signing, and measured performance. Gate: R1 release checklist. Collect personal-use evidence for at least several varied work sessions; do not substitute a polished animation for integration reliability.

## M4 — iPhone companion

Outcome: selected conversations and last-observed state are available on iPhone; supported links open in its own provider sessions. TASK-030 through TASK-034. First prove the proposed synchronization transport, then implement versioned snapshots, enrollment, local phone cache, foreground refresh, mobile destinations, and sign-out/deletion handling. Gate: R2 acceptance on a physical iPhone.

Do not add remote sending as a shortcut to making Mac-only sessions actionable. Those entries can be visible and clearly labelled without pretending a mobile route exists.

## M5 — Opt-in previews

Outcome: the latest message can be inspected without opening the original tool where an adapter supports reading it. TASK-040. Use a bounded excerpt cache, precise provenance, independent opt-in, expiration, and Open original. Gate: TEST-017 and no accidental collection when disabled. No model calls needed.

## M6 — Explicit-target composer

Outcome: user-authored input reaches a supported selected chat with truthful delivery state. TASK-050. Spike each source before enabling send. Draft-only is acceptable where safe send cannot be established, but must be labelled. The source UI retains approval decisions. Gate: TEST-018, target/epoch verification and uncertain-outcome handling.

## M7 — Optional summaries

Outcome: the user can opt into a labelled generated summary of selected preview content. TASK-060. Select local/cloud processing, consent, source-revision invalidation, and retention. Gate: TEST-019 and original text always available. Costs and provider terms need current verification before implementation.

## Development tooling milestone

TASK-070 may implement a read-only MCP wrapper around the existing Markdown registry after the source files and local retrieval prove useful. It is separate from the customer app and does not grant access to users' chats. TASK-071 adds controlled mutations only if required. The project can be developed without any MCP server.

## Estimates and scheduling

Earlier conversation estimates were rough hypotheses: 2–3 focused days for a narrow prototype, 1–2 weeks for a useful personal Mac slice, and roughly 3–6 weeks for a narrow Mac/iPhone beta. They assume full-time AI-assisted work, reuse, supported integrations, and a ready Mac toolchain; they are not delivery commitments. Re-estimate after M1 using actual integration results. Multi-provider desktop status and composer support can dominate the schedule. Scope/gates are more reliable than blanket “AI time” conversions.

## Rules for execution plans

Create a plan in `plans/` for a multi-step integration, risky migration, or substantial feature. Include purpose, current context, implementation sequence, interfaces, dependencies, validation, recovery, progress, discoveries, decisions, and outcomes. Name real paths/commands when known; label future targets explicitly. Small edits can use the task row alone.

Keep plans resumable without this conversation. Preserve important findings and failed approaches that affect the next decision. Close a plan with measured outcomes and remaining limits. Do not require an agent to reread every document to fix a typo.
