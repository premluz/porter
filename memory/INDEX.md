---
id: "DOC-INDEX"
type: "index"
title: "Generated project memory index"
status: "active"
updated: "2026-10-13"
owner: "project-maintainer"
tags: ["area/memory", "phase/foundation"]
summary: "Generated entry points and topic map; rebuild with the local utility."
related: ["DOC-README", "DOC-MEMORY"]
---

# Project memory index

Generated from current document metadata. Do not edit this table by hand.

Start with [current state](../PROJECT_STATE.md) and [handoff](HANDOFF.md). Use [task status](../TASKS.md) to select work. Read deeper documents only as needed.

| ID | Document | Status | Tags | Purpose |
| --- | --- | --- | --- | --- |
| ADR-001 | [Navigation-first product boundary](../decisions/ADR-001-navigation-first.md) | accepted | area/product, area/security, phase/r1 | Records the user-selected shortcut-first product boundary. |
| ADR-002 | [Native Mac shell and browser connector](../decisions/ADR-002-native-and-extension.md) | proposed | area/macos, area/browser, area/identity, phase/r1 | Proposed implementation split for native UI and browser-aware navigation. |
| ADR-003 | [Metadata-only iPhone sync proposal](../decisions/ADR-003-mobile-sync.md) | proposed | area/ios, area/sync, area/security, phase/r2 | Proposed simple iPhone companion and unresolved transport constraints. |
| ADR-004 | [Suite reference contract for Manager, Atlas, and Memento](../decisions/ADR-004-suite-references.md) | proposed | area/product, area/identity, area/security, phase/r1 | How Porter links to sibling-product records without becoming their source of truth. |
| ADR-005 | [Prototype local IPC: same-user Unix sockets](../decisions/ADR-005-prototype-local-ipc.md) | proposed | area/macos, area/browser, area/security, phase/r1 | Why the bridge prototype uses Unix domain sockets instead of the XPC service ADR-002 proposed, and what that does not yet protect. |
| ADR-006 | [Native-first sources, optional enhancers](../decisions/ADR-006-native-first-sources.md) | proposed | area/macos, area/browser, area/identity, area/release, phase/r1 | v1 is one installable app that observes browsers, desktop apps and editors natively; the browser extension and editor companion become optional enhancers behind the same adapter boundary. |
| ADR-007 | [The panel outline is a traced distance field, fused with the screen edge](../decisions/ADR-007-liquid-outline.md) | accepted | area/macos, area/ux, phase/r1 | The docked tab, the capsule and the pane are one rounded box fused with the screen edge by a gradient-aware smooth minimum, traced into a path on the CPU each frame, so the native material, the clip and the edge line keep working and no move ever shows a seam. |
| ADR-008 | [Opt-in local speech and evidence-based completion notices](../decisions/ADR-008-voice.md) | accepted | area/macos, area/ux, area/security, phase/r1 | Apply PLAN-004 defaults: structural completion evidence, metadata-only local speech, push to talk first, and distinct interruptions. |
| DOC-AGENTS | [Shared agent instructions](../AGENTS.md) | active | area/memory, phase/foundation | Small shared entry point for coding agents. |
| DOC-ARCHITECTURE | [Component architecture](../docs/ARCHITECTURE.md) | draft | area/macos, area/browser, area/ios, area/identity, phase/r1, phase/r2 | Proposed component boundaries, event flow, and synchronization. |
| DOC-CLAUDE | [Claude Code entry point](../CLAUDE.md) | active | area/memory, phase/foundation | Routes Claude Code to the shared project instructions. |
| DOC-CONSTITUTION | [Project constitution](../CONSTITUTION.md) | active | area/product, area/security, area/memory, phase/foundation | Product principles and boundaries for implementation decisions. |
| DOC-DATA | [Data model and protocol contracts](../docs/DATA_CONTRACTS.md) | draft | area/identity, area/browser, area/macos, area/ios, phase/r1 | Conversation identity, status evidence, IPC, and later send semantics. |
| DOC-FACTS | [Durable project facts](../memory/FACTS.md) | active | area/memory, area/product, phase/foundation | User requirements and established findings with evidence classification. |
| DOC-FACTS-FOUNDATION | [Foundation facts FACT-001 to FACT-020](../memory/facts/FOUNDATION.md) | archived | area/memory, phase/r1 | Preserved records split to keep documents under 200 lines. |
| DOC-HANDOFF | [Current handoff](../memory/HANDOFF.md) | active | area/memory, phase/foundation, phase/r0 | Minimal restart packet for the next implementation agent. |
| DOC-LOG-20261008-1 | [Progress 20261008, part 1](../memory/progress/2026-10-08-1.md) | archived | area/memory, phase/r1 | Preserved records split to keep documents under 200 lines. |
| DOC-LOG-20261008-2 | [Progress 20261008, part 2](../memory/progress/2026-10-08-2.md) | archived | area/memory, phase/r1 | Preserved records split to keep documents under 200 lines. |
| DOC-LOG-20261009-1 | [Progress 20261009, part 1](../memory/progress/2026-10-09-1.md) | archived | area/memory, phase/r1 | Preserved records split to keep documents under 200 lines. |
| DOC-LOG-20261009-2 | [Progress 20261009, part 2](../memory/progress/2026-10-09-2.md) | archived | area/memory, phase/r1 | Preserved records split to keep documents under 200 lines. |
| DOC-LOG-20261010-VOICE-CUES | [Voice cue and recognition checkpoint](../memory/progress/2026-10-10-voice-cues.md) | active | area/macos, phase/r1 | Push-to-talk start/stop cues and partial recognition retention. |
| DOC-MEMORY | [Project memory and MCP contract](../docs/MCP_MEMORY.md) | active | area/memory, area/mcp, area/security, phase/foundation | Portable Markdown conventions, tagging, retrieval, and future MCP tools. |
| DOC-PLAN | [Delivery roadmap](../PLANS.md) | active | area/product, area/quality, phase/foundation, phase/r0, phase/r1, phase/r2 | Milestones, dependency order, and planning conventions. |
| DOC-PROGRESS | [Project progress log](../PROGRESS.md) | active | area/memory, phase/foundation | Append-only checkpoint history with evidence and next actions. |
| DOC-QUESTIONS | [Open questions and risks](../memory/QUESTIONS.md) | active | area/memory, area/identity, area/security, area/sync, phase/r0 | Unresolved choices and experiments that can settle them. |
| DOC-README | [Conversation Switcher — project entry](../README.md) | active | area/product, area/memory, phase/foundation | Entry point and navigation for the complete project pack. |
| DOC-SCOPE | [Technical scope and release boundaries](../docs/TECHNICAL_SCOPE.md) | draft | area/product, area/macos, area/browser, area/ios, phase/r1, phase/r2 | Testable functional requirements and phased scope. |
| DOC-SECURITY | [Security and privacy boundaries](../docs/SECURITY_PRIVACY.md) | draft | area/security, area/identity, area/browser, area/ios, phase/r1, phase/r2 | Concrete data access and destination-protection requirements. |
| DOC-SOURCES | [Sources and attribution](../docs/SOURCES.md) | active | area/memory, area/mcp, area/browser, area/macos, phase/foundation | Published sources and the limits of their applicability. |
| DOC-STATE | [Current project state](../PROJECT_STATE.md) | active | area/memory, area/product, phase/foundation | Short current checkpoint and exact next action. |
| DOC-TASKS | [Canonical task ledger](../TASKS.md) | active | area/product, area/memory, area/quality, phase/foundation | Single task-status source with dependencies and completion evidence. |
| DOC-TEMPLATES | [Reusable record templates](../templates/RECORDS.md) | template | area/memory, area/quality, phase/foundation | Small templates for tasks, evidence, decisions, plans, and handoffs. |
| DOC-UX | [UX and visual design specification](../docs/UX_DESIGN.md) | draft | area/ux, area/macos, area/ios, phase/r1, phase/r2 | Interaction flows, liquid-glass motion, and accessibility behavior. |
| DOC-VALIDATION | [Validation and release plan](../docs/VALIDATION_RELEASE.md) | draft | area/quality, area/macos, area/browser, area/ios, phase/r1, phase/r2 | Evidence requirements, test matrix, and release procedures. |
| DOC-VALIDATION-MANUAL | [Existing manual validation batches](../docs/VALIDATION_MANUAL.md) | active | area/memory, phase/r1 | Preserved records split to keep documents under 200 lines. |
| DOC-VOICE-VALIDATION | [Voice validation and batch U](../docs/VOICE_VALIDATION.md) | active | area/quality, area/macos, area/security, phase/r1 | Scripted voice checks, recognition evidence gate, and human sound review. |
| PLAN-001 | [Prove the Mac conversation-switcher foundations](../plans/PLAN-001-feasibility.md) | active | area/macos, area/browser, area/identity, area/quality, phase/r0 | Executable first milestone with platform experiments and evidence gates. |
| PLAN-002 | [v1: one installable app that reads every source](../plans/PLAN-002-v1-app-package.md) | active | area/macos, area/browser, area/release, phase/r1 | Native-first source adapters, feasibility spikes, and the single app package with a setup assistant. |
| PLAN-003 | [Docked, floating and open: moving the panel and snapping it to the edge](../plans/PLAN-003-dock-states.md) | active | area/macos, area/ux, phase/r1 | Three panel states (docked tab, floating capsule, open pane), dragging with a magnetic pull to the edge, reflow to a horizontal strip near the top or bottom, and hover to peek. |
| PLAN-004 | [Hands-free: completion notices, spoken announcements and voice navigation](../plans/PLAN-004-voice.md) | active | area/macos, area/ux, area/security, phase/r1 | Announce when an agent's turn ends (notification and, optionally, a spoken line with the task's name) and let the person say "Porter, show the task" or "show <name>" to bring it forward; all on the Mac, no cloud, no tokens. Dictating replies is the later composer milestone. |
| PLAN-005 | [Live mascot: one character spec, shared animation rules, a liquid body that splits into agents](../plans/PLAN-005-live-mascot.md) | proposed | area/macos, area/ux, phase/r1 | Turn the Rios Brand capsule-eye mascot into a live, expressive character: eyes that follow the cursor, blink and change expression, and a liquid body that can split into two or three agents and merge back. Rios Brand owns the character spec and a web renderer; Porter reads the spec and runs the same rules natively. |

The JSON catalog also records content hashes and line counts. Neither index is a replacement for current source files. The MCP interface is proposed, not installed.
