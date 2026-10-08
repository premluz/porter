---
id: "DOC-SCOPE"
type: "spec"
title: "Technical scope and release boundaries"
status: "draft"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/product", "area/macos", "area/browser", "area/ios", "phase/r1", "phase/r2"]
summary: "Testable functional requirements and phased scope."
related: ["DOC-CONSTITUTION", "DOC-ARCHITECTURE", "DOC-UX", "DOC-VALIDATION"]
---

# Technical scope

## Product definition

Conversation Switcher is a personal Mac utility for returning to conversations across supported AI tools. A conversation may be working, waiting for input, inactive but still relevant, or pinned for later. “Active” in the product means user-relevant; it is not restricted to an agent currently executing.

The iPhone companion offers an optional synchronized view and supported mobile destinations. Future capabilities add latest-message previews, an explicit-target composer, and optional summaries. These are separate releases because their permissions and integration needs differ.

## Release map

| Release | Included | Explicit boundary |
| --- | --- | --- |
| R0 feasibility | Real Mac/browser bridge, profile identity, desktop-link investigation, glass study | Developer prototype; no reliability or compatibility claims |
| R1 Mac switcher | Mac edge panel; Chrome connector; open/recent/pinned list; exact-tab activation; limited supported status; pinned desktop links | No phone sync, messages, summaries, terminal control, or autonomous routing |
| R2 iPhone companion | Optional enrolled-device metadata sync; freshness; mobile web/deep links; offline list | Does not inherit Mac login, control arbitrary iOS apps, or provide a system-wide overlay |
| R3 previews | Opt-in latest-message excerpt per supported source | No full conversation archive or AI summarization by default |
| R4 composer | Explicit target, user text, supported send/draft path, delivery reporting | No approval delegation, autonomous agent selection, bulk broadcast, or blind retries |
| R5 summaries | Opt-in summary of selected content with provenance | Never replaces original approval/question text |

“Full scope” means this complete roadmap; only R0/R1 are the first implementation commitment. R2 is part of the intended product. R3–R5 are staged options, not assumed shipped features.

## Requirements

| ID | Requirement | Release | Acceptance |
| --- | --- | --- | --- |
| REQ-001 | Native Mac edge capsule and expandable pane | R1 | Click/shortcut reveals pane; Escape restores capsule without stealing focus afterward |
| REQ-002 | Discover open supported web conversations | R1 | Conversation title and destination appear after supported navigation without manual URL entry |
| REQ-003 | Keep ordinary chats as well as working tasks | R1 | Idle chats remain open/recent; pinning retains them after closing |
| REQ-004 | Activate the exact existing destination | R1 | Correct browser profile, window, and tab receive focus in a two-profile test |
| REQ-005 | Separate conversation from destination | R1 | Duplicate tabs can coexist; unverified account identities are not merged |
| REQ-006 | Preserve account/session boundaries | R1 | Sign-out or account change invalidates prior identity/status; no automatic login switching |
| REQ-007 | Show evidence-backed status and freshness | R1 | Adapter loss/frozen tab shows unknown or stale; never newly “done” |
| REQ-008 | Support keyboard, screen reader, reduced motion/transparency | R1 | Core navigation works without pointer or color interpretation |
| REQ-009 | Pin a desktop chat link | R1 | Validated supported link opens correct chat on tested app version; unsupported links explain fallback |
| REQ-010 | Restore pins, hide choices, and placement | R1 | Relaunch restores preferences; stale tab IDs are reconciled, not reused blindly |
| REQ-011 | Disconnect a source and delete its collected metadata | R1 | Collection stops and selected records disappear; no unrelated source is affected |
| REQ-012 | Native setup and diagnosable connection failures | R1 | Extension/helper status is visible; denied permissions do not crash core UI |
| REQ-013 | Sync selected metadata to enrolled iPhone | R2 | Foreground phone refresh sees a versioned snapshot; offline records show age |
| REQ-014 | Open an appropriate phone destination | R2 | Supported mobile URL/deep link opens; Mac-only entries are clearly labelled |
| REQ-015 | Revoke device sync and handle signed-out cloud account | R2 | Revoked enrollment receives no new payload; local Mac remains usable |
| REQ-016 | Display latest message when enabled | R3 | Exact excerpt, source, timestamp, and truncation marker are shown; disable deletes cache |
| REQ-017 | Compose for an explicit conversation/account | R4 | Target is fixed and revalidated before send; uncertain outcome is visible and not retried blindly |
| REQ-018 | Summarize selected latest content | R5 | Summary is labelled generated and links to original; provider/model and content revision recorded |
| REQ-019 | Portable project memory | Foundation | Fresh agent can locate current task, decision, and evidence through Markdown or local search |
| REQ-020 | Optional development-memory MCP | Later tooling | Read-only tools return document IDs, revisions and citations; access is confined to this repository |

## Integration target order

1. Chrome on macOS, one extension package installed separately in each enabled profile. Browser profile label can be user-assigned; do not assume Chrome exposes its UI profile name to extensions.
2. ChatGPT web and Claude web as first intended providers. URL/title discovery can be supported before status. Every capability remains unverified until the installed-page spike is recorded.
3. Desktop ChatGPT/Claude/Codex links where supported. Manual pinning first; automatic discovery only after a documented interface is proven.
4. Terminal coding agents only through a later explicit adapter. Generic terminal text scraping is not required for R1.

Safari, Firefox, additional Chromium browsers, Windows, Android, and remote Linux connectors are outside the initial release. They are not implied by broad “all agents” marketing.

## Functional boundaries

- Default list: pinned followed by open and recent, with stable ordering while the pane is being used.
- Proposed recent-history retention: seven days; pinned items survive until removed. A user can clear recent items.
- Discover only supported conversation routes, not every visited page. New chats without a stable provider ID remain session-local until a real ID appears.
- Each source declares capabilities independently: discover, observe status, activate, mobile open, preview, draft, send.
- Missing capabilities must not be simulated as working. A manually pinned chat can remain useful with unknown status.
- Mac R1 is local only. No model call, cloud account, provider credential import, or paid backend is necessary.
- Do not promise to list provider account history; discovery covers observed sessions and explicitly added links.

## Performance targets to measure

Targets are provisional acceptance budgets, not measurements: pane interaction p95 below 150 ms; pane animation 220–320 ms; navigation dispatch p95 below 250 ms, with user-visible focus evaluated separately; live status propagation p95 below 2 seconds when the source is awake; idle CPU below 1% of one core on the agreed reference Mac; memory below 150 MiB for the Mac UI/service at 100 destinations, excluding browser usage. Measure energy use, not just frame rate. Raise a recorded issue rather than hiding misses.

## Platform and distribution assumptions

Proposed first native-glass baseline: macOS 26+ and iOS 26+, Apple silicon first. Validate actual SDK API availability and the user's hardware in TASK-010. The project should build in Xcode on a Mac. This package was prepared in a Linux workspace and cannot establish native behavior.

Proposed Mac distribution: Developer ID signed and notarized app plus explicit browser-extension installation. Proposed phone distribution: TestFlight for the beta. Signing identity, bundle IDs, release tooling, update channel, and store submission decisions are setup work, not pre-existing assets.

## Scope-change triggers

Automatic approval, autonomous sending, screen recording, credential extraction, reading all chat history, cross-user sharing, and remote terminal execution materially change the product. Record their tradeoffs before implementing if the user requests them. Routine UI and adapter improvements inside the stated boundaries do not need extra approval.
