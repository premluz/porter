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

## LOG-20261008-009 — Panel feedback: smoother morph, bounce, stagger, scrollbar

- Date: 2026-10-08.
- Author: assistant; feedback from Prem after running the sample panel: aesthetics and glass look good, opening felt slightly jittery, scrollbar flashed during resize and hide, and a Spotlight-like bounce and staggered fade-in were requested, using a native liquid transition if one applies.
- Tasks: TASK-014, TASK-023.
- Changed: the window is now set once to the pane size when opening (and back to the capsule size when fully closed) and only the glass shape animates inside it, using a spring with one bounce and the SDK's `glassEffectID` / `matchedGeometry` glass transition; this replaces per-frame window resizing. Search, rows and footer fade and lift in with a short stagger. The list's scroll indicators are hidden except while a scroll is in progress. Reduce Motion uses a short fade with no bounce; Reduce Transparency uses an opaque surface. Removed the old progress-based curves and their tests. Timing values live in `Tokens.Motion`.
- Verified (automated): Mac app 37 tests; `Porter --self-test` passes, including that the capsule keeps its screen position inside the pane window.
- Not verified: how it now looks and feels, whether the glass morph renders as intended, whether the bounce is right, whether the scrollbar stays hidden when it should, and the brief period during a move when the window is pane-sized (so a transparent area is present for a fraction of a second). Previous behavior is in commit 92b0dbf if this should be reverted.
- Next action: Prem re-runs manual batch step A2 and A3.

## LOG-20261008-010 — VS Code probe built; account-wide route ruled out

- Date: 2026-10-08.
- Author: assistant; Prem chose a VS Code companion extension (Q-020) and asked whether an account API or login could list all sessions and where they run.
- Tasks: TASK-015.
- Tags: area/macos, area/security, area/identity, phase/r1.
- Answers recorded: Anthropic's terms forbid Porter from offering Claude.ai login or storing or relaying Claude.ai credentials or session tokens, and no documented API lists claude.ai conversations or local Claude Code sessions (S14, FACT-019). A Claude Code session does know its host (its environment names the entry point, here `claude-vscode`), and each VS Code window leaves a lock file naming the IDE, process and workspace beside a websocket token; those are undocumented internals holding tokens, mostly stale, and Porter does not read them.
- Changed: `extensions/vscode`, a development-only extension that (1) lists Claude Code editor tabs in its window by webview type `claudeVSCodePanel`, (2) tries to bring a chosen tab forward with built-in editor-group and editor-index commands and judges the result from VS Code's own tab API, and (3) registers `vscode://porter-dev.porter-vscode-probe/focus?label=...` so an outside link can trigger the same. It sends nothing anywhere. `scripts/link-dev.sh link|unlink` links it into `~/.vscode/extensions` without packaging.
- Verified: 8 tests of the pure logic pass (tab detection, identical titles, position limits, verdict rules, link parsing); the extension typechecks and builds; the link script was run against a temporary folder only.
- Not verified: everything that needs a running VS Code. Whether the tab type name is right, whether position commands reach the tab, whether an outside link reaches the right window when several are open, and whether the OpenAI extension's chats can be seen the same way.
- Next action: Prem runs the probe (manual batch F); the result decides the shape of the real companion.

## LOG-20261008-011 — VS Code probe: tab detection and focus observed in one window

- Date: 2026-10-08.
- Author: assistant; observations by Prem in VS Code 1.140 (window "Porter").
- Tasks: TASK-015.
- Tags: area/macos, area/identity, phase/r1.
- Verified (observed, one window, one Claude Code tab): the probe loads from the linked folder; "List Claude Code tabs" found the open Claude Code tab with its group, position and active state, so the webview type `claudeVSCodePanel` is right; "Test bringing a Claude Code tab forward", with a file tab in front, brought the Claude Code tab forward and the tab list confirmed it (reported by Prem as worked; the exact verdict line was not pasted). Tab titles can be truncated with an ellipsis ("Porter macOS edge panel …").
- Verified (observed, `vscode://` link): a link sent from Terminal with a file tab in front reached the extension in the window, matched the Claude Code tab by its (truncated) title, and brought it forward twice (`worked`); the text cursor landed in the chat input. An earlier send with the tab already in front correctly reported `alreadyActive` and did nothing. The first send showed a VS Code confirmation popup for the extension link; Prem chose its "don't show again" option, so whether the prompt would recur without it is not known.
- Not verified: more than one VS Code window (which window receives a link), a link sent while another app is in front, identical titles, tabs in other editor groups, whether Porter can use a title as the identifier, and the OpenAI extension.
- Verified (observed, two windows): with a second VS Code window in front, a link for a tab in the first window brought nothing forward; links go to the focused window, which found no matching tab. A companion therefore cannot rely on the link alone and must first bring the right window forward.
- Verified (observed): `open -a "Visual Studio Code" <folder>` brought the existing window for that folder forward without creating a new window (tried twice); doing that, waiting 1.5 seconds and then sending the link brought the first window forward and flipped it to its Claude Code tab. The route window-by-folder then tab works from another VS Code window. Not tried: another app in front, several windows on nested folders, multi-root workspaces, windows with no folder.
- Decision: build the real companion on this route. Each window reports its Claude Code tabs to the registry over the local socket; Porter opens the window's folder, then sends an activation request over the same socket (no `vscode://` link and no confirmation popup). VS Code tabs have no stable ID, so identity is workspace plus title plus ordinal and a rename changes it (a documented limit).
- Next action: contract and core changes for editor tabs, then the companion, then the panel.

## LOG-20261008-012 — VS Code companion built

- Date: 2026-10-08.
- Author: assistant.
- Tasks: TASK-015.
- Tags: area/macos, area/identity, area/security, phase/r1.
- Changed: contracts and core gained a `vscode` connector kind (IDs prefixed `vscode-`), editor tab reports and an `editorTab` destination, an optional `editor` target in activation requests, and an activation "prepare" step. Editor connectors report whole snapshots only; browser and editor kinds cannot be mixed (tested both ways, with a mutation check). The registry service opens the window's folder, waits 0.8 s, then sends the request; the connector's own check decides the outcome. `extensions/vscode` is now the companion: it connects straight to the registry socket (no relay), derives its identity from the window's folder, reports Claude Code tabs, and answers activation requests only if position, title and a derived identity all still agree, confirming success from VS Code's tab API. The probe's link handler and countdown test were removed. The panel and recovery messages say VS Code for VS Code items, and the recovery action launches the right application.
- Verified (automated): contracts 11 schemas / 65 fixtures; ConversationCore 75 tests, PorterPanelModel 39; native-host 16 (three new use a fake editor window over the real socket); Mac app 38; companion 34 (including that everything it sends satisfies the shared schemas). A real Node companion connected to the real Swift registry over a temporary socket: it appeared as a `vscode-` connector with two routes for two same-titled tabs and went disconnected when it stopped.
- Not verified: the companion inside a running VS Code; the folder-opening step triggered by the Mac app (observed working by hand earlier); the panel showing VS Code rows; any multi-root workspace, remote window, or window without a folder (those are not reported by design); the OpenAI extension.
- Known limits recorded: an editor tab has no stable ID, so identity is folder plus title plus order and a rename makes a new route (FACT-020); a snapshot is capped to fit the 64 KiB frame (it reports how many were left out); there is no continuity memory for editor routes.
- Next action: Prem runs manual batch F.

## LOG-20261008-013 — Newest-first ordering, ChatGPT in VS Code (Codex), ChatGPT web diagnostics

- Date: 2026-10-08.
- Author: assistant; requests from Prem: the most recent chats should be on top, and ChatGPT is needed both on the web and in VS Code. Prem also found that the "missing" Claude Code chat had been listed all along, below the visible part of the list.
- Tasks: TASK-015, TASK-021, TASK-023.
- Tags: area/macos, area/browser, area/identity, phase/r1.
- Changed (recency): tab reports gained an optional `lastActiveAt` (contract, core, rows, panel). The registry stores it per route without changing the revision, so reordering never invalidates a selection. The Open list sorts newest first, then items without a time, then a stable order; pinned items keep your order; the order on screen is still frozen while the pane is open. Chrome reports its own last-accessed time, raised to the window's focus time for the active tab. The VS Code companion tracks when each tab became the focused one (VS Code reports no such time); tabs never focused since the window opened carry none.
- Changed (ChatGPT in VS Code): the companion now matches several providers. `codex` covers the OpenAI extension's webview panel (`chatgpt.panelView`) and custom editor (`chatgpt.conversationEditor`), taken from that extension's manifest and code, together with `claude-code`. Conversation IDs now include the provider, so same-titled tabs of different providers stay separate. A new diagnostic command lists every tab's kind and view type in a window. Rows read "ChatGPT Codex" and their messages name VS Code.
- Changed (ChatGPT web): the existing adapter is unchanged (`chatgpt.com/c/<id>`, still marked untested); the extension now logs the address shape (identifiers hidden) of any tab on an allowed site that no adapter recognises, once per shape.
- Verified (automated): contracts 11 schemas / 67 fixtures; ConversationCore 79, PorterPanelModel 45, native-host 16, Mac app 38; Chrome extension 35; VS Code companion 42. A real Node companion reported a Codex tab with a time and a never-focused Claude Code tab without one to the real Swift registry, which decoded both.
- Not verified: how the new ordering feels; the Codex tab types at runtime (the OpenAI extension's side-panel view is not an editor tab and will not appear); any ChatGPT web chat; window-focus recency in practice.
- Next action: Prem runs manual batches E0, E1 and F9, and reports any `[porter] ... not recognised` lines and the diagnostic output for a Codex tab.

## LOG-20261008-014 — Agent working state from Claude Code hooks

- Date: 2026-10-08.
- Author: assistant; Prem reported that every chat showed the same dotted "unknown" circle and asked for agent working state.
- Tasks: TASK-013 (status), TASK-015, TASK-023.
- Tags: area/identity, area/security, area/macos, phase/r1.
- Why unknown until now: nothing Porter could observe says whether a chat is busy; that was by design (no guessing). Claude Code hooks are a documented, explicit signal (S15), so they are used for Claude Code only.
- Changed: `AgentEvent` (whitelisted fields only) with strict validation, the event-to-state rules, and per-tab attribution in the core; a control-socket command for events; `porterctl hook` (prints nothing, always exits 0, quick, errors only on stderr) and `porterctl hook-config`; `claude-hooks.sh` to add or remove Porter's hooks in a Claude settings file (dry run by default, backup, keeps everything else) with a test script; the Mac app reads the registry's statuses and re-checks them when the pane opens.
- Attribution rules (a wrong "Working" is worse than none): the session must be from the VS Code extension, inside the window's folder (deepest window wins), with exactly one Claude Code tab and one such session; otherwise Unknown.
- Verified (automated): ConversationCore 92 (13 new, plus a mutation check on the entrypoint rule), native-host 23 (7 new, including the real `porterctl hook` binary with a fake window), Mac app 39; the install script's own test; privacy tests showing prompt text, tool input and transcript path never reach an event or an error message.
- Not verified: any real Claude Code session; whether user-level hooks fire for the VS Code extension; how the status reads in use; browser chats and Codex (no signal; Q-023); several tabs per window (Q-024).
- Not done on purpose: your Claude settings were not changed. Applying the hooks is a step for you (batch H).
- Next action: Prem runs batch H.

## LOG-20261008-015 — Opening animation rebuilt and measured; window outline

- Date: 2026-10-08.
- Author: assistant; Prem reported a square-looking border around the pane and that opening had become abrupt after the previous motion rework.
- Tasks: TASK-014, TASK-023.
- Tags: area/macos, area/ux, phase/r1.
- Finding: the previous rework animated nothing visible. A new probe that reads the shape's laid-out size on each frame showed it jumping from the 40 pt capsule to the full pane in one step. Swapping two glass shapes and relying on SwiftUI's implicit morph was the wrong foundation, and I had not measured it before shipping it.
- Changed: the motion is now explicit. A spring (`SpringCurve`) computed from the clock gives a progress value, a `TimelineView` redraws one persistent glass shape each frame at that progress, and the dots and the pane's content fade by fixed fractions of it. A move reversed halfway starts from the shape's current size. The window gets a margin while opening so the bounce is not clipped, then shrinks to the pane. The pane is now built once at launch and kept mounted but invisible: building it at the first frame of the move caused a ~75 ms stall (the jitter noticed before). Reduce Motion uses a short critically damped move with no bounce. The system window shadow is turned off: it was computed once for the window's pixels and could not follow the shape, which is the likely cause of the square outline.
- Measured (`Porter --probe-animation`, three runs): the shape grows smoothly through 21–23 distinct sizes, frames every ~13–17 ms from the first, peaks at 375 pt (a 15 pt bounce) and settles at 360 pt in about 500 ms; the one run that closed itself early was an outside interruption. Unit tests cover the spring (endpoints, overshoot matching its formula, no overshoot without bounce, settling), reversal continuity and the content phases; Mac app 51 tests.
- Not verified: the square outline is gone (the cause is inferred, not photographed); how the motion feels; behavior with many rows; Reduce Motion and Reduce Transparency visually.
- Next action: Prem re-runs batch A2 and A3 and says whether the outline and the abruptness are fixed.

## LOG-20261008-016 — Content fades in last; glass edge rebuilt after the window resizes

- Date: 2026-10-08.
- Author: assistant; Prem asked for the inner items to be staggered with easing so they are fully visible only toward the end, and reported that after a collapse the glass border disappeared on the last frame and returned only after pressing and dragging the panel.
- Tasks: TASK-014, TASK-023.
- Tags: area/macos, area/ux, phase/r1.
- Finding: the spring takes the shape to its full size in about a third of the move and then bounces, so any fade tied to the shape's progress is complete early. The content needs its own clock.
- Changed: `MotionState.contentProgress` runs linearly over the move (closing runs 0.4× as long), rows start at 0.25 and follow one another by 0.035 with a 0.45 smoothstep each, so the last row is complete at about 0.98 of the move. Reversal continues from the current value. For the border: the likely cause is that the glass draws its edge when built and nothing redrew it after the window shrank and resigned key with the timeline paused (dragging forced a redraw). The glass surface is now rebuilt (`refreshSurface`, new identity) one turn after the window has settled, on collapse and on open.
- Follow-up (Prem: border still missing after `aefa37c`): rebuilding the SwiftUI glass was not enough, so the collapse now also re-attaches the hosting view to the window, redisplays and re-orders it (`reattachContent`), to make the window server re-register the window as a mouse event does. Still a guess: this machine has no screen-capture permission, so I could not photograph the panel before or after.
- Second follow-up: Prem still sees the border missing after a collapse and says it shows only while the panel is pressed and held. That points to an inactive-window look rather than a stale redraw, so the root view now sets `controlActiveState` to key. A hypothesis again; no screen capture is available here.
- Verified: Mac app 52 tests; `--self-test` passes; `--probe-animation` 22 distinct sizes, settles at 360 pt.
- Not verified: that the border now stays (a cause inferred from the symptom, not reproduced or photographed); how the new fade feels.
- Next action: Prem re-runs batch A2 and A3, checking the border after collapse and the fade timing.

## LOG-20261008-017 — Pane shows the six most recent; older conversations fold into a group

- Date: 2026-10-08.
- Author: assistant; Prem asked for the last six used to show and the rest in an expandable group.
- Tasks: TASK-014.
- Tags: area/macos, area/ux, phase/r1.
- Changed: the pane's "Open" section lists the six newest unpinned conversations; any beyond that sit under an "Older (N)" header that expands and collapses on click. Pinned items do not count toward the six. Arrow-key selection reaches folded rows only while the group is open, and a search shows every match with the group open. The split is `PanelSnapshot.recentSplit` (core, tested); the open/closed state is `AppModel.olderExpanded`. The iPhone list is unchanged and still shows every open conversation. The capsule's dots follow the reachable list, so they no longer include folded conversations.
- Verified: core 49 tests (4 new), Mac app 53 (1 new), `--self-test` passes.
- Not verified: how the group looks and feels; the pane keeps the height it opened with, so expanding a long group scrolls rather than growing it.
- Next action: Prem tries it with more than six chats open.

## LOG-20261009-001 — v1 direction: native-first sources, one app package

- Date: 2026-10-09.
- Author: assistant; Prem decided v1 must be one installable app that reads VS Code, the ChatGPT app, the Claude app and browser chats, that other models, browsers and editors must be easy to add, and that the browser extension stays at v0.1 as a secondary route.
- Tasks: TASK-027, TASK-080 to TASK-084.
- Tags: area/macos, area/release, phase/r1.
- Changed: recorded ADR-006 (native tier primary, extension and editor companion as optional enhancers, identity reported as unknown rather than guessed when a profile cannot be told), PLAN-002 (adapter boundary, three feasibility spikes, setup assistant, signed package), five task rows, and a pointer from ADR-002. One assumption stated in ADR-006: VS Code keeps its companion as the primary route.
- Not verified: every native route. Chrome scripting, Accessibility for the ChatGPT and Claude apps, and external extension install are untested here; the spikes decide.
- Next action: TASK-080, then the spikes.

## LOG-20261009-002 — Adapter boundary for in-app sources (TASK-080)

- Date: 2026-10-09.
- Author: assistant.
- Tasks: TASK-080.
- Tags: area/macos, area/browser, phase/r1.
- Changed: core gained `ProviderRecognizer` (Claude and ChatGPT rules in Swift, parity cases copied from the extension's tests) and `HostConnector` (snapshot, activate, change stream). `RegistryService.attach` runs a `HostConnector` inside the app and joins it to the registry through a socket pair speaking the normal wire protocol, so every existing registry rule applies without a second code path. `ActivationResult` got a public initializer; `serveBridge` is no longer private. Existing connectors and behavior are untouched.
- Verified: core 96 tests (4 new recognizer tests), native-host 27 (4 new: inventory lifecycle, activation round trip, failed activation passed on, duplicate installation refused), Mac app 53, all passing.
- Not verified: no real host exists yet; the spikes (TASK-081 to TASK-083) provide the first. `ConnectorKind` still has only chrome and vscode; native kinds and any contract change come with the spike that needs them.
- Next action: TASK-081, the Chrome and Safari scripting spike.

## LOG-20261009-003 — Chrome and Safari scripting spike (TASK-081)

- Date: 2026-10-09.
- Author: assistant; Prem approved the spike (tab listing filtered to claude.ai and chatgpt.com, other tabs counted only) and opened a second-profile window and a Safari tab for it.
- Tasks: TASK-081.
- Tags: area/browser, area/macos, phase/r1.
- Result: go for the native tier (FACT-024). Both browsers list their tabs and can bring a chosen one forward with no extension, across Chrome profiles; stable ids in Chrome. No profile property exists, so Porter shows the profile as unknown and the same chat open in two profiles as ambiguous. Incognito windows are listed and must be excluded by default. No last-used time exists.
- Slip to disclose: a check of window names printed one non-Claude tab title that I had said I would not read; I did not keep it anywhere.
- Not verified: which profile each window belongs to, the permission prompt for Porter itself, Safari beyond one window, and what the screen showed during activation (checked through Chrome's own report).
- Next action: TASK-082, the ChatGPT and Claude desktop apps through Accessibility; that also needs the Accessibility permission, so it needs Prem's go-ahead. It can try reading the Chrome profile button too.

## LOG-20261009-004 — Desktop apps through Accessibility (TASK-082)

- Date: 2026-10-09.
- Author: assistant; Prem granted Accessibility to a separate helper app (PorterSpike, since removed) and agreed to one chat being opened in each desktop app.
- Tasks: TASK-082.
- Tags: area/macos, area/browser, phase/r1.
- Result: go with limits (FACT-025). Both apps' sidebars are readable and a chat can be opened by pressing its entry. Identity is only the title and position, not an id; the ChatGPT app shows an "Unread" marker that could feed status. Chrome's profile name is readable from its accessibility window title (FACT-024).
- Slips to disclose: the first helper runs printed more than I had said they would, because they filtered by control type. One printed Gmail inbox rows and a Claude chat's message-action labels, a later one printed links from inside chat messages. I deleted those outputs, recorded none of it, and then limited the tool to the left 300 points of each window. I also deleted a run's output file while its process was still writing to it.
- Cleanup: helper app removed from the Desktop and its permission entry reset.
- Not verified: the apps' behavior when hidden or on another desktop, duplicate titles, and the real Porter app's permission prompt.
- Next action: TASK-083 (VS Code companion install from the bundle; Accessibility fallback assessment), then TASK-084.

## LOG-20261009-005 — VS Code companion packaging spike (TASK-083)

- Date: 2026-10-09.
- Author: assistant.
- Tasks: TASK-083.
- Tags: area/macos, area/release, phase/r1.
- Result: see FACT-026. The companion packs into a `.vsix` with a small script (no new dependency), and each editor's own command installs, lists and removes it. Only throwaway folders were used, so your real editors and extensions were not touched.
- Changed: added `extensions/vscode/scripts/package-vsix.sh` (with `--verify`) and listed it in the validation doc. Tested with a wrong command path, which fails with a message.
- Not verified: the companion running inside Cursor or Windsurf, and a running window picking up a command-line install.
- Next action: TASK-084, the setup assistant. It needs a design decision from Prem on the first-launch checklist.

## LOG-20261009-006 — Native Chrome connector, slice 1: contracts, core, extension-wins rule (TASK-085)

- Date: 2026-10-09.
- Author: assistant.
- Tasks: TASK-085.
- Tags: area/browser, area/macos, phase/r1.
- Changed: new connector kind `chromeScripting` in the connector and hello schemas (two fixtures) and in the core. It behaves like a browser connector (tabs, incremental updates, no editor tabs) and has no profile. Connector summaries now carry the connector type. The panel builder drops a scripted route when an extension route exists for the same provider and conversation, so a chat is not listed twice, and keeps scripted-only routes. Cost, written in the code: a chat open in a profile with the extension and in another without it shows only the extension's route.
- Verified: contracts validate (69 fixtures); core 99 tests (7 new, one mutation-checked by disabling the rule); native-host 27; Mac app 53.
- Not verified: no connector produces this kind yet.
- Next action: slice 2, the connector itself (script generation from the recognizers' hosts, parsing, polling, activation by window and tab id, incognito excluded).

## LOG-20261009-007 — Native Chrome connector: connector and app wiring (TASK-085)

- Date: 2026-10-09.
- Author: assistant.
- Tasks: TASK-085.
- Tags: area/browser, area/macos, phase/r1.
- Changed: new `NativeSources` library in the native-host package: a script runner (child `osascript`, 5 s limit), the list and activate scripts for a Chromium browser (windows addressed by id; only provider hosts requested; incognito skipped), a parser, and `ChromeScriptingConnector`, a `HostConnector` that polls every 2 s, reports changes, orders by when a tab was last visible, and re-checks the target before bringing it forward (gone, changed, permission refused, timed out). It never asks a browser that is not running, because scripting would launch it. Recognizers now list their hosts. The Mac app attaches the connector at launch with a stable installation id; it can report `health` for the setup screen.
- Verified: native-host 38 tests (11 new, including an end-to-end run through the registry with polling and activation, and a runner fake); a live check against this Mac's real Chrome returned its three conversation tabs in 0.29 s with incognito and non-chat pages excluded (counts only, no titles printed); Mac app 53; core 99. I did not start the app against your running instance.
- Not verified: the app as a whole with this source (batch I), the permission prompt for Porter itself, and a profile-less route next to an extension route in the real panel.
- Open: nothing tells the user when permission is refused; that belongs to the setup screen (TASK-084). Only Chrome is wired; other Chromium browsers are a value in `ChromiumBrowser` once their dictionaries are checked.
- Next action: Prem runs batch I. Then TASK-086 (desktop apps) or TASK-087 (Safari), or the setup screen.

## LOG-20261009-008 — Desktop-app connectors, slice 1: contracts and core (TASK-086)

- Date: 2026-10-09.
- Author: assistant.
- Tasks: TASK-086.
- Tags: area/macos, area/browser, phase/r1.
- Changed: new connector kind `desktopApp` for the Claude and ChatGPT desktop apps. Contracts: `appEntries` in the snapshot, an `appEntry` destination locator, an `app` target in the activation request, six fixtures (two invalid: extra message text, ordinal out of range). Core: entries are routes keyed by a connector-derived id (title plus position among equal titles, so a rename or a moved duplicate looks new, as with VS Code tabs); snapshots replace the list; only the two known bundle ids are accepted; the connector may not report tabs or editor tabs, and a browser or editor connector may not report app entries. The panel model knows the two apps as hosts, with their own "not open" message, and the permission-refused message no longer says only "extension".
- Verified: contracts validate (75 fixtures); core 106 tests (7 new); native-host 38; Mac app 53.
- Not verified: nothing reads an app yet.
- Next action: slice 2, the Accessibility reader, per-app adapters and the connector, tested on synthetic trees shaped like the ones the spike saw.

## LOG-20261009-009 — Desktop-app connectors, slice 2: reader, adapters, connector, wiring (TASK-086)

- Date: 2026-10-09.
- Author: assistant.
- Tasks: TASK-086.
- Tags: area/macos, area/browser, phase/r1.
- Changed: in `NativeSources`: an accessibility abstraction (a node protocol so everything runs on synthetic trees; a live implementation on one serial queue that asks Chromium apps to build their tree), a sidebar strip that reads only the leftmost 300 points of a window (message text sits outside it), adapters for the Claude app and the ChatGPT app (OpenAI's `com.openai.codex`) and `DesktopAppConnector`. It reports a layout it does not recognise (sidebar closed, no Recents list) as a failure with a reason, never as an empty list; keeps the last list when the window cannot be read; never asks an app that is not running; reports `permissionDenied` without the Accessibility permission; and before pressing an entry re-reads the sidebar and checks title and position (gone, changed, or pressed, then brings the app forward). Ids are a short digest of the title plus an ordinal among equal titles. The app's list position is carried as `position` so the panel keeps the app's newest-first order when no time is known, which makes "most recent six" follow the app. The Mac app attaches the connector at launch and asks for the permission once per launch while untrusted.
- Verified: native-host 54 automated tests, 14 of them new for desktop apps (adapters, connector, registry end to end, all on synthetic trees with placeholder titles; one more live test is off by default); core 106; contracts 75 fixtures; Mac app 53; release build. A mutation or live check was not possible for the readers: this Mac's terminal has no Accessibility permission, so the live test is gated and was not run.
- Not verified: everything against the real apps (batch J). The adapter rules come from one observed layout per app and may be wrong for pinned chats, older groups or other states; that is why an unrecognised layout is an error, not an empty list.
- Next action: Prem runs batches I and J, then the setup screen (TASK-084).

## LOG-20261009-010 — Setup window (TASK-084, first slice)

- Date: 2026-10-09.
- Author: assistant.
- Tasks: TASK-084.
- Tags: area/macos, area/ux, phase/r1.
- Changed: a "Set up Porter" window, opened on first launch and from the menu bar, lists each source with a state (ready, needs your permission, not open, optional, checking) and one action: open System Settings at Automation, prompt for Accessibility and open that pane, or open the app. Rows come from a pure checklist function over plain inputs (source health, connected connectors, installed VS Code-family editors, whether Claude Code's settings carry Porter's hook), so it is tested without this Mac's state. Sources that are not attached are not listed. The automatic Accessibility prompt at launch is gone; the window owns it. The window refreshes every 2 s while open.
- Verified: Mac app 61 tests (8 new); the headless self-test lays the window out at 520 pt wide; release build.
- Not verified: how it looks (no screenshots here; a person should judge), the permission prompts end to end, and the wording. Not built: installing the enhancers from the window; that waits for the bundled app (TASK-027) and the extension-install test.
- Next action: Prem runs batches I, J and K and says what is unclear or wrong. Then the bundled app and installer (TASK-027), and the Chrome extension install route.

## Checkpoint format

Use the log template in [record templates](templates/RECORDS.md). Keep logs concise; link detailed test evidence instead of pasting terminal transcripts. Rotate older entries into dated files after approximately 150 entries or 64 KiB, preserving all LOG IDs and updating the index.
