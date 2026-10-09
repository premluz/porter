---
id: "DOC-TASKS"
type: "tasks"
title: "Canonical task ledger"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/product", "area/memory", "area/quality", "phase/foundation"]
summary: "Single task-status source with dependencies and completion evidence."
related: ["DOC-PLAN", "DOC-PROGRESS", "DOC-VALIDATION"]
---

# Task ledger

Statuses: `todo`, `in_progress`, `blocked`, `done`, `deferred`, `cancelled`. A dependency in this table is a hard prerequisite unless the active plan explains otherwise. Owner `unassigned` means unclaimed. A task becomes done only when its acceptance has evidence.

| ID | Priority | Phase | Status | Owner | Depends on | Deliverable and completion evidence |
| --- | --- | --- | --- | --- | --- | --- |
| TASK-001 | P0 | M0 | done | assistant | — | Scope/memory documentation pack authored; LOG-20261008-001 |
| TASK-002 | P0 | M0 | done | assistant | TASK-001 | Documentation, retrieval and tooling validated; LOG-20261008-002; final archive contains the validated folder |
| TASK-010 | P0 | M1 | done | assistant | TASK-002 | Inventory real Mac/Xcode/browser/phone; settle minimum OS and tested app list; LOG-20261008-003, FACT-009. No physical iPhone listed: device inventory moves to TASK-030 |
| TASK-011 | P0 | M1 | done | assistant | TASK-010 | Two-profile bridge, handshake, activation, reconnect proof; TEST-001, TEST-002, TEST-011; LOG-20261008-004 to -007, FACT-013/014/015. Limits: connectorOffline and tab-moved-between-windows not observed in real Chrome; registry run from a terminal; ADR-002 stays proposed until TASK-014 |
| TASK-012 | P0 | M1 | done | assistant | TASK-010 | Implement schemas and core identity/status reducer with invalidation tests; LOG-20261008-003 (9 schemas, 29 fixtures, 32 Swift tests) |
| TASK-013 | P0 | M1 | in_progress | assistant | TASK-011, TASK-012 | Verify intended providers' URL/title/status and one native deep link; record limitations. Done: desktop link research (FACT-016), Claude chat link built and tested in code, ChatGPT web adapter added as untested. Outstanding: live test of the Claude link, any status signal, ChatGPT page check |
| TASK-014 | P1 | M1 | in_progress | assistant | TASK-010 | Native glass morph prototype, interruption, reduced settings; TEST-009. Implemented and headless-checked (LOG-20261008-008); needs a person to judge the glass, animation, click-through and Spaces behavior |
| TASK-015 | P1 | M1 | in_progress | assistant | TASK-011 | VS Code companion: probe verified in two windows (LOG-20261008-010, -011); real companion built and tested (LOG-20261008-012); now also Codex tabs, recency and ChatGPT web diagnostics (LOG-20261008-013). Agent working state from Claude Code hooks built (LOG-20261008-014). Outstanding: manual batches E0, E1, F and H in a running VS Code |
| TASK-020 | P0 | M2 | done | assistant | TASK-012 | Shared Swift core, local store and migration fixtures; PorterStore (pins, hidden, per-source deletion) with migration tests, LOG-20261008-008. Limit: migrations tested with a synthetic second version, since no real v2 exists |
| TASK-021 | P0 | M2 | in_progress | assistant | TASK-011, TASK-013 | Chrome discovery and lifecycle for first provider, then second. Claude web observed in real Chrome; adapter registry built; ChatGPT web adapter present but untested |
| TASK-022 | P0 | M2 | in_progress | assistant | TASK-020, TASK-021 | Real pane-to-destination activation and typed error UX. Implemented with typed recovery messages and tests; the live Mac app against real Chrome is untested |
| TASK-023 | P1 | M2 | in_progress | assistant | TASK-014, TASK-020 | Capsule/pane/search/pins/keyboard UI using agreed design. Implemented; unreviewed by a person (TEST-008 to TEST-010 pending) |
| TASK-024 | P0 | M2 | todo | unassigned | TASK-022, TASK-023 | Integrate real sources; identity/status/restart acceptance TEST-001–007 |
| TASK-025 | P0 | M3 | todo | unassigned | TASK-024 | Permission/source management, deletion and diagnostics; TEST-011–012 |
| TASK-026 | P0 | M3 | todo | unassigned | TASK-024 | Accessibility, Spaces, multi-display, energy/performance evidence |
| TASK-027 | P0 | M3 | in_progress | assistant | TASK-025, TASK-026, TASK-084 | App package for v1 (PLAN-002): `build-app.sh` makes an ad-hoc-signed `Porter.app` (helpers, VS Code companion, signed Chrome extension package, hook installer); `build-dmg.sh` makes `Porter.dmg`; the setup window installs the optional pieces and toggles open-at-login (LOG-20261009-011, -012). Outstanding: Developer ID signing and notarization (needs the Apple Developer account; script steps written, not run), updates, a clean-account install test, and a person trying the install buttons and Chrome's approval prompt |
| TASK-028 | P1 | M3 | todo | unassigned | TASK-027 | Release notes, compatibility table, update/rollback plan |
| TASK-080 | P0 | M3 | done | assistant | TASK-012 | Source-adapter boundary: `HostConnector` and `ProviderRecognizer` in core, Swift recognizers for Claude and ChatGPT with parity tests, `RegistryService.attach` for in-app connectors; LOG-20261009-002. The extension and companion are unchanged: they are the same boundary spoken over the socket |
| TASK-081 | P0 | M3 | done | assistant | TASK-080 | Spike: Chrome and Safari tabs via Apple Events without an extension. Go for the native tier with profile unknown (FACT-024; LOG-20261009-003). Not covered: profile pairing of scripted and accessibility windows, the extension install route (moves to TASK-084) |
| TASK-082 | P0 | M3 | done | assistant | TASK-080 | Spike: ChatGPT and Claude desktop apps via Accessibility. Go with limits: sidebar titles and an "Unread" marker readable, pressing a chat opens it; identity is the title and position only (FACT-025; LOG-20261009-004) |
| TASK-083 | P1 | M3 | done | assistant | TASK-080 | Spike: VS Code companion installed from a command line in VS Code, Cursor and Windsurf (FACT-026; `package-vsix.sh`; LOG-20261009-005). Accessibility fallback assessed and not recommended. Not covered: the companion's behavior inside Cursor and Windsurf, a reload of a running window |
| TASK-085 | P0 | M3 | in_progress | assistant | TASK-081 | Native Chrome connector (`chromeScripting`): contracts, core kind, extension-wins rule, connector (script, parsing, polling, activation re-check, incognito excluded) and app wiring done and tested with a fake runner and once against the real Chrome (LOG-20261009-006, -007). Outstanding: batch I run by a person; the permission explanation in the setup screen (TASK-084) |
| TASK-086 | P0 | M3 | in_progress | assistant | TASK-085, TASK-082 | Native connector for the Claude and ChatGPT desktop apps through Accessibility: contracts, core, adapters, connector, app wiring and the app's own ordering built and tested on synthetic trees (LOG-20261009-008, -009). Outstanding: batch J run by a person against the real apps (the adapters rest on one observed layout each); unread marker as status; the permission explanation in the setup screen (TASK-084) |
| TASK-087 | P1 | M3 | todo | unassigned | TASK-085 | Safari native connector through Apple Events |
| TASK-088 | P1 | M3 | in_progress | assistant | TASK-086 | Codex threads from Codex's own list (VS Code and app), opened through their owners' links: reader, connector, contracts, panel and setup built and tested; the live read works (LOG-20261009-018). Outstanding: batch N, a person trying each kind of link |
| TASK-084 | P0 | M3 | in_progress | assistant | TASK-081, TASK-082, TASK-083 | Setup window: a checklist of sources with state, permission buttons and optional enhancer rows is built and tested (LOG-20261009-010; batch K). The window now installs the optional pieces from the bundled app (LOG-20261009-011). Outstanding: per-source on/off; seen by a person (batches K and L) |
| TASK-029 | P0 | M3 | todo | unassigned | TASK-028 | Personal-use beta review and R1 acceptance evidence |
| TASK-030 | P0 | M4 | todo | unassigned | TASK-029 | Validate CloudKit proposal, enrollment, freshness, deletion, sign-out; decide ADR-003 |
| TASK-031 | P0 | M4 | todo | unassigned | TASK-030 | Versioned metadata DTO, snapshot sync and phone cache |
| TASK-032 | P0 | M4 | todo | unassigned | TASK-031 | iPhone list/detail UI and real mobile destination behavior. An early sample-data target exists ahead of TASK-031 as the kickoff asked (builds for the simulator; no sync, no real destinations) |
| TASK-033 | P0 | M4 | todo | unassigned | TASK-032 | Offline/revocation/conflict tests and physical-device acceptance |
| TASK-034 | P1 | M4 | todo | unassigned | TASK-033 | TestFlight packaging and R2 release evidence |
| TASK-040 | P2 | M5 | deferred | unassigned | TASK-029 | Opt-in previews and bounded cache; requires preview adapter spike |
| TASK-050 | P2 | M6 | deferred | unassigned | TASK-029 | Explicit-target composer; source-specific capability and delivery proof |
| TASK-060 | P2 | M7 | deferred | unassigned | TASK-040 | Labelled summaries, processing choice and provenance |
| TASK-070 | P2 | Tooling | todo | unassigned | TASK-002 | Optional read-only MCP wrapper for development docs; TEST-021 |
| TASK-071 | P3 | Tooling | deferred | unassigned | TASK-070 | Optional revision-checked memory/task writes with audit and locking |

## Claim and update protocol

When multiple contributors are authorized, claim a task with owner/session ID and current timestamp before editing the same files. Declare intended paths in the active plan. A Markdown claim is a coordination convention, not a distributed lock: use separate worktrees/branches and merge review for concurrent changes, or a serialized MCP writer when implemented.

Do not overwrite another contributor's uncommitted changes or force-update a stale task record. Mark blocked with a concrete reason and next resolution action. On completion, add evidence in PROGRESS.md and update this row in the same change. Deferred tasks are roadmap options, not blocked work that must be started immediately.
