---
id: "DOC-PROGRESS"
type: "log"
title: "Project progress log"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "phase/foundation"]
summary: "Append-only checkpoint history with evidence and next actions."
related: ["DOC-README", "DOC-TEMPLATES"]
---

# Progress log

Append checkpoints in date order. Each event uses a unique LOG ID, author, task IDs, evidence, limits, and next action. Use UTC timestamps when the actual time is known; a date alone is preferable to an invented time. Corrections are new entries referencing the old entry.

## LOG-20261008-001 — Project foundation created

- Date: 2026-10-08.
- Author: assistant; product direction supplied by Prem.
- Tasks: TASK-001.
- Tags: area/memory, area/product, phase/foundation.
- Outcome: created the project constitution, full staged scope, architecture, UX, data contracts, privacy boundaries, acceptance matrix, roadmap, task ledger, memory taxonomy, MCP interface proposal, decision records, and first implementation plan.
- Evidence: the linked Markdown files in [README](README.md); published guidance is linked in [sources](docs/SOURCES.md).
- Decisions: ADR-001 records the navigation-first baseline. ADR-002 and ADR-003 are proposed technical defaults.
- Limits: no product code or native integrations implemented; no private vendor-team practices verified; no MCP server connected.
- Validation: documentation-tool verification is recorded in the subsequent validation event when actually completed.
- Next: finish documentation validation, then execute TASK-010 on a Mac.

## LOG-20261008-002 — Documentation and memory tooling verified

- Date: 2026-10-08.
- Author: assistant.
- Tasks: TASK-002.
- Tags: area/memory, area/quality, phase/foundation.
- Outcome: validated 25 Markdown documents, 27 task records, relative file links, related document IDs, tag vocabulary, task dependencies, and generated catalog freshness.
- Commands: `python3 tools/project_memory.py index`; `python3 tools/project_memory.py check`; `python3 tools/test_project_memory.py`.
- Verified: eight behavioral tests passed, including retrieval/tag filters, bounded reads, stale-index detection/rebuild, broken-link detection, duplicate-ID rejection, dependency-cycle rejection, path-input rejection, and symlink escape rejection. Search for account with area/identity returned the relevant identity and architecture documents.
- Packaging: deliver the complete folder in a ZIP while preserving relative links; no product app or MCP server is included.
- Limits: these results validate project documentation/tooling only. No macOS/iOS build, provider adapter, cloud sync, or live MCP connection was tested.
- Next: TASK-010 on a real Mac using PLAN-001.

## LOG-20261008-003 — Mac inventory, shared contracts and core logic

- Date: 2026-10-08.
- Author: assistant (Claude Code); kickoff brief and dependency approval from Prem.
- Tasks: TASK-010, TASK-012.
- Tags: area/identity, area/macos, area/quality, phase/r0.
- Changed: recorded the reference environment (FACT-009). Added `packages/contracts` (9 draft 2020-12 schemas, valid/invalid fixtures, Ajv validator via npm) and `packages/ConversationCore` (Swift 6.4 package: records, locator policy, identity keys, envelope header decoder, event sequencer, status projection, destination registry, suite context links). Added ADR-004 and FACT-010/011, Q-014/015.
- Verified: `npm run validate` gave "9 schemas compiled, 29 fixtures behaved as expected". Each invalid fixture was checked to fail on its intended rule. `swift test --package-path packages/ConversationCore`: 32 tests in 5 suites passed, covering same-title chats, unknown accounts, account-epoch change, replay, sequence gap, stale working status, page-clock skew, conflicting routes and rejected URL schemes. iOS Simulator `xcodebuild` build succeeded.
- Not verified: no app, extension, native host or real browser data. Message-ID deduplication and typed payload decoding are not implemented. TypeScript types are not generated yet.
- Memento: the Porter project was found with 248 indexed entries and no subjects. Five suggested subjects were proposed (Destination identity, Status observation, Shared contracts, Suite context references, Platform inventory) and await owner review. A change report was filed against them.
- Decisions: ADR-004 proposed.
- Next action: TASK-011 two-profile Chrome bridge under PLAN-001 step 2.

## LOG-20261008-004 — Chrome bridge built and verified with a simulated Chrome

- Date: 2026-10-08.
- Author: assistant (Claude Code); dependency approval from Prem.
- Tasks: TASK-011 (in progress; the real two-profile run is outstanding).
- Tags: area/browser, area/macos, area/identity, area/security, phase/r1.
- Changed: bridge payload schemas and fixtures; `BridgeCoordinator` and typed message decoding in `packages/ConversationCore`; new `services/native-host` package (framing, same-user Unix sockets, registry service, `porter-native-host` relay, `porter-registryd`, `porterctl`, install and uninstall scripts); new `extensions/chrome` (MV3, TypeScript, optional host permission for claude.ai only, no content script, no page reading, options page for profile name and permission). ADR-005 proposed; FACT-012/013 added.
- Verified: contracts 10 schemas / 44 fixtures; ConversationCore 51 tests; native-host 13 tests including a real relay binary driven by simulated Chrome profiles (identical titles stay two routes, activation reaches only the chosen profile, forged connector refused without wiping the victim's tabs, unapproved origin refused, duplicate installation refused, unanswered activation times out); extension 25 tests including schema validation of its own output; smoke run of the release binaries; install and uninstall scripts against temporary directories. A mutation check confirmed the forged-connector test fails without its guard.
- Not verified: real Chrome profiles, the real claude.ai URL and title behavior (the " - Claude" title suffix is an assumption), Chrome launching the host, service-worker lifetime, whether the registry can bring Chrome forward, restart reconciliation in practice. Account identity stays Unknown and status stays Unknown by design.
- Evidence: FACT-013, docs/VALIDATION_RELEASE.md procedure.
- Decisions: ADR-005 proposed (Unix sockets for the prototype instead of XPC).
- Memento: change report filed against the existing subjects.
- Next action: Prem runs the two-profile procedure; record the results and then mark TASK-011 done or document the narrower fallback.

## LOG-20261008-005 — Real Chrome: one profile detected, listed and activated

- Date: 2026-10-08.
- Author: assistant; run by Prem on the reference Mac (FACT-009), Chrome 154.
- Tasks: TASK-011 (still in progress).
- Tags: area/browser, area/macos, area/identity, phase/r1.
- Changed: ran `install-dev.sh` against the real Chrome folder, loaded the unpacked extension in one profile, started `porter-registryd`.
- Verified (observed, one profile): the host was found after install; the extension connected; a real claude.ai chat tab appeared in `porterctl list` with its title and tab/window IDs; two tabs of the same chat appeared as two routes marked ambiguous; `porterctl activate` returned `activated`. The first attempt was not conclusive because the chat tab was already visible. A second, clean attempt with a google.com tab in front switched the browser to the claude.ai chat tab (observed by Prem). Activating a route whose tab had been closed and reopened returned `targetGone` and focused nothing, and the new tab appeared as a new route with a new ID. The profile name can be changed in Options and the connector reconnects under the new name.
- Verified (observed, two profiles): a second Chrome profile loaded the same unpacked extension and appeared as a separate connector with its own route ("Get Panta" and "Prem2", different installation IDs). Activating a route in the other profile switched to that profile's window and chat, in both directions, while Prem was in a different profile's window. With a non-Chrome application in front, activating a route brought Chrome forward on the chosen chat (the registry was started from a terminal, not from the Mac app).
- Verified (TEST-001, observed): with the chat in the second profile renamed so both profiles showed the identical title "Test", `porterctl list` showed two rows with different profile names and route IDs, and activating each reached the correct profile's window in both directions. A title rename did not change the route revision.
- Not verified: Chrome quit and relaunched (reconnect, new route IDs); service-worker restart behavior over time.
- Open observation: the Options page and registry first reported 0 tabs while a claude.ai chat existed; they showed it after the tab was reopened or refreshed. The cause is not established (possibilities: a chat started on `/new` before its `/chat/<id>` address, or a snapshot taken before the tab was visible to the extension). It needs a repeatable reproduction before any fix.
- Next action: rename one chat so both profiles show the same title, then the remaining negative cases (targetChanged, Chrome quit and relaunch) in docs/VALIDATION_RELEASE.md.

## LOG-20261008-006 — Route IDs changed after a chat rename; fixed and re-observed

- Date: 2026-10-08.
- Author: assistant; observations by Prem in real Chrome.
- Tasks: TASK-011 (still in progress).
- Tags: area/browser, area/identity, phase/r1.
- Found: renaming a chat in one real profile gave its route three different IDs in a few minutes (each old ID refused with `targetGone`, which is the intended safe outcome). The registry log showed no reconnects, only tab-list updates. The code explains the rest: a tab missing from one tab list was forgotten, and its return created a new route ID. A rename in the other profile did not do this.
- Changed: `BridgeCoordinator` now remembers the ID and revision of a route that leaves the tab list, bounded to 500 and discarded on any reconnect. A returning tab showing the same chat gets its old ID with a higher revision; a different chat in the same tab number, or a reconnect, gets a new ID. Six new tests (ConversationCore now 57); a mutation check confirmed the main tests fail without the ID reuse.
- Verified (observed): after restarting the registry with the fix, renaming the chat updated the listed title and kept the same route ID while the revision rose, which shows the tab did drop out of a tab list and came back under its old ID.
- Not established: why that profile's tab drops out of the tab list during a rename. The extension builds the list from the tab URL and title, so a momentary mismatch is the likely area, but nothing has been measured. The registry also logs "inventory changed" for every tab list, even identical ones, which made the log noisy.
- Verified (observed, `targetChanged`): after the same tab was navigated to a different chat, its route kept its ID and the revision rose; activating the earlier revision was refused with `targetChanged` and opened nothing, and the current revision activated the new chat.
- Next action: Chrome quit and relaunch (`connectorOffline`, new IDs).

## LOG-20261008-007 — TASK-011 closed: Chrome quit and relaunch observed

- Date: 2026-10-08.
- Author: assistant; observations by Prem in real Chrome (two profiles, Chrome 154).
- Tasks: TASK-011 (done), supporting TASK-012.
- Tags: area/browser, area/identity, phase/r1.
- Verified (observed): with Chrome quit, both connectors showed disconnected and no routes remained, and activating an old route returned `targetGone` with nothing opened. After Chrome was reopened, both profiles reconnected on their own within about 30 seconds. After a chat was opened in each profile, both appeared as new routes with new tab numbers and new IDs; the pre-restart IDs were refused with `targetGone`; activating a new route brought the correct profile window forward.
- Differs from expectation: the routes disappeared on quit rather than staying visible as disconnected, because the extension sends empty tab lists as Chrome closes its tabs. `connectorOffline` is therefore covered by unit and simulated-Chrome tests only; a real-Chrome case needs the browser to be killed rather than quit.
- Summary for TASK-011 acceptance: TEST-001 (identical titles, two profiles, both directions), TEST-002 (closed tab and navigated tab refused safely; a tab moved between windows was not tested), TEST-005 (restart reconciles, old locators not reused), TEST-011 (forged, replayed, oversized and unknown-version input rejected, simulated Chrome only), plus Chrome brought forward from another application. Limits: registry ran from a terminal rather than the Mac app; one Chrome version and one provider (claude.ai web); title behavior observed only as shown by Porter, not captured raw; the cause of the tab dropping out of a tab list during a rename is unexplained.
- Next action: TASK-014 (Mac panel prototype) and an early iOS app target are independent of each other; TASK-013 (provider status and desktop deep links) can follow. Choose one.

## LOG-20261008-008 — Mac app, phone app, packets, stores and adapters built (batch for human testing)

- Date: 2026-10-08.
- Author: assistant; Prem authorised continuing without per-step approval and testing in one later batch.
- Tasks: TASK-013 (partly), TASK-014, TASK-020 (done), TASK-021, TASK-022, TASK-023; early part of TASK-032; Phase 3 suite links.
- Tags: area/macos, area/ios, area/browser, area/identity, area/security, phase/r1.
- Changed: `packages/ConversationCore` gained `PorterStore` (SQLite pins and hidden items with migrations) and `PorterPanelModel` (panel contents, keyboard selection, typed recovery messages, status wording, sample data, context packet review); `DesktopLinks` builds only the documented `claude://claude.ai/chat/<id>` link. New `apps/macos` (SwiftUI panel in a non-activating AppKit window with native Liquid Glass, global shortcut ⌃⌥Space, menu-bar item, embedded registry, sample mode). New `apps/ios` (hand-written Xcode project, sample-data list and detail). Extension: provider adapter registry, ChatGPT adapter (untested, off until granted), per-site permissions page, tab-dropout diagnostics. Registry logs only real changes. New schema `context-packet` (11 schemas, 54 fixtures).
- Verified (automated): contracts 11 schemas / 54 fixtures; ConversationCore 62 tests; PorterStore 14; PorterPanelModel 34; native-host 13; Mac app 37; extension 33; iOS app builds for the simulator and ran headless once; `Porter --self-test` passed (real panel and views built off screen, window frames equal the geometry, shortcut registered). Mutation checks were run on the route ID reuse and forged-connector tests.
- Found late and fixed: the final full run showed the self test failing because AppKit snaps a window to whole points while the geometry produced a half point (457.5 against 457.0), which appeared once the usable screen area became fractional. The geometry now returns whole-point frames and a test covers fractional screens. The self test now prints the real and expected frames when it fails.
- Not verified: how the panel looks or feels (glass, motion, corner shape, Reduce Motion and Transparency, Spaces, two displays, click-through of empty areas, VoiceOver); the Mac app against real Chrome; the Claude desktop link in the installed app; the ChatGPT adapter on a real page; any status signal; the phone beyond one screenshot of sample data.
- Decisions: ADR-004 refined by the implemented packet contract; desktop links limited to the documented existing-chat form (S12); packets are held in memory only.
- Corrections: a sources entry was first numbered S11 in error (S11 already existed); it is S12, and the ChatGPT note was folded into S09.
- Next action: Prem runs the manual batch in docs/VALIDATION_RELEASE.md and reports what differs.

## Checkpoint format

Use the log template in [record templates](templates/RECORDS.md). Keep logs concise; link detailed test evidence instead of pasting terminal transcripts. Rotate older entries into dated files after approximately 150 entries or 64 KiB, preserving all LOG IDs and updating the index.
