---
id: "DOC-FACTS"
type: "memory"
title: "Durable project facts"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "area/product", "phase/foundation"]
summary: "User requirements and established findings with evidence classification."
related: ["DOC-CONSTITUTION", "DOC-SOURCES", "DOC-QUESTIONS"]
---

# Durable facts

Evidence classes: `user_requirement`, `source_documentation`, `verified_test`. Proposed implementation choices belong in ADRs/questions, not as verified facts. User evidence below is the current project conversation on 2026-10-08; no external transcript is required to interpret the recorded requirement.

## FACT-001 — Product unit is a conversation

- Class: user_requirement.
- Statement: include ongoing ordinary chats as well as agents actively working. Clicking an item should return to its original chat/window.
- Source: user's simplification of One into a cross-tool conversation shortcut utility.
- Tags: area/product, phase/r1.
- Implication: conversation/destination identity must be modeled separately from running processes.

## FACT-002 — Mac and phone are intended surfaces

- Class: user_requirement.
- Statement: user requested a Mac-only desktop app and a mobile phone experience.
- Source: user's request to scope technical, visual, and UX layers.
- Tags: area/macos, area/ios.
- Caveat: iPhone is our proposed mobile assumption; Android exclusion is not an explicit user platform selection.

## FACT-003 — Visual direction

- Class: user_requirement.
- Statement: minimal Apple-style design, Liquid Glass, and a pane emerging from the screen edge through a liquid transition.
- Source: user's visual/UX scope request.
- Tags: area/ux, phase/r1.

## FACT-004 — Decisions stay with the source tool

- Class: user_requirement.
- Statement: shortcut navigation is the base product. The user prefers bringing up the original decision interface over routing decisions through this tool.
- Source: user's security/simplicity rationale.
- Tags: area/security, area/product.
- Caveat: this does not mean the switcher accesses no data; titles, URLs, status, and future previews are still data access.

## FACT-005 — Composer and summaries are potential extensions

- Class: user_requirement.
- Statement: user suggested a universal composer to pass input to a selected chat and later latest-message or summarized-message views.
- Source: user's future-feature discussion.
- Tags: area/product, phase/r3, phase/r4, phase/r5.
- Caveat: not approved as a universal integration claim or R1 requirement.

## FACT-006 — Portable agent memory requested

- Class: user_requirement.
- Statement: user requested Markdown constitution, full technical scope, work plan, progress log, tagging, and MCP-friendly navigation for other agents.
- Source: current documentation task.
- Tags: area/memory, area/mcp, phase/foundation.

## FACT-007 — Browser tab metadata is not agent state

- Class: source_documentation.
- Statement: Chrome tab APIs describe tab/window identity, loading, and suspension; agent working/waiting status needs a provider-specific observation path.
- Source: [S04](../docs/SOURCES.md), checked 2026-10-08.
- Tags: area/browser, area/identity.
- Implication: an unknown/stale status is a supported outcome.

## FACT-008 — Project implementation has not started

- Class: verified_test is not applicable; artifact inventory fact.
- Statement: foundation consists of documents and a local documentation utility. Product components and MCP transport are not implemented.
- Source: this project's current artifact inventory; see [state](../PROJECT_STATE.md).
- Tags: area/memory, phase/foundation.
- Review trigger: first code scaffold; update this fact and retain historical evidence in PROGRESS.md.
- Superseded 2026-10-08 by FACT-010.

## FACT-009 — Reference Mac environment

- Class: verified_test (local inventory commands, 2026-10-08).
- Statement: macOS 26.6.2 (25G83), arm64; Xcode 27.0 (27A266a) with macOS 27.0 and iOS 27.0 SDKs; Swift 6.4; Node 22.22.2; iOS 27.0 simulator runtime. Chrome 154.0.8037.98 (`com.google.Chrome`, installed as `/Applications/Google Chrome 2.app`, 5 profiles). Safari 26.6.2. `/Applications/Claude.app` 2.26454.2 (`com.anthropic.claudefordesktop`, registers the `claude` URL scheme). `/Applications/ChatGPT.app` 26.924.22138 is bundle `com.openai.codex` and registers `codex`, not a ChatGPT chat scheme. No physical iPhone was listed by `devicectl`.
- Source: `sw_vers`, `uname -m`, `xcodebuild -version`/`-showsdks`, `defaults read <app>/Contents/Info`, `xcrun simctl list runtimes`, `xcrun devicectl list devices`.
- Tags: area/macos, area/browser, area/ios, area/release.
- Implication: a registered scheme is not a verified chat deep link (TASK-013). The ChatGPT desktop target must be clarified as Codex or a separate ChatGPT install.
- Review trigger: any OS, Xcode or app update before compatibility claims.

## FACT-010 — Contracts and core package exist

- Class: verified_test.
- Statement (as of LOG-20261008-003; counts have grown, see FACT-013): `packages/contracts` (9 JSON Schemas, 29 fixtures) and `packages/ConversationCore` (Swift package, 32 tests) exist and pass; the package also builds for the iOS Simulator. No app, extension or native host existed at that point.
- Source: LOG-20261008-003.
- Tags: area/identity, area/quality, phase/r0.
- Review trigger: next scaffold milestone.

## FACT-011 — Porter name and suite boundaries

- Class: user_requirement (kickoff brief, 2026-10-08).
- Statement: the product is named Porter. Its siblings are Manager (planning, tasks, timelines; working name), Atlas (visual capture and annotation), and Memento (project memory and source-linked context). Porter owns destinations, observed activity and user-directed handoff, and is not the source of truth for Manager tasks or Memento documents. The phone surface is iPhone. Chrome comes first; Safari (macOS and iOS) follows only after its own permission, packaging and release checks. The iOS target should build early.
- Source: user kickoff brief in the project conversation.
- Tags: area/product, area/ios, area/browser.
- Implication: ADR-004; resolves Q-003; changes Safari's placement (Q-014).

## FACT-012 — Chrome native messaging and service worker rules

- Class: source_documentation (accessed 2026-10-08).
- Statement: a host manifest has `name`, `description`, `path`, `type: stdio` and `allowed_origins` (no wildcards); the name allows only lowercase letters, digits, underscores and dots. On macOS the per-user manifest goes in `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/<name>.json`. Messages are UTF-8 JSON with a 32-bit length in native byte order, at most 1 MB from host to Chrome and 64 MiB from Chrome to host. Chrome passes the caller's origin (`chrome-extension://<id>/`) as the host's first argument. The extension needs the `nativeMessaging` permission. An open `runtime.connectNative` port keeps an MV3 service worker alive (Chrome 105+); if the host exits, the port closes and the worker may stop, so the extension reconnects in `onDisconnect`. A service worker otherwise stops after 30 seconds of inactivity.
- Source: https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging and https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle (the fetched summaries did not state the 105+ keep-alive for connectNative on the first page; the second page did).
- Tags: area/browser, area/macos.
- Implication: the relay enforces its own 64 KiB cap; the extension adds an alarm so a stopped worker reconnects. Real Chrome behavior is still unmeasured here.

## FACT-013 — Bridge verified with a simulated Chrome

- Class: verified_test.
- Statement: on the reference Mac (FACT-009) the following pass: `packages/contracts` 10 schemas and 44 fixtures; `swift test` for `packages/ConversationCore` (51 tests, including forged-message, replay, gap, duplicate-installation, identical-title and moved-target cases, and a mutation check that the forged-connector test fails when its guard is removed); `swift test` for `services/native-host` (13 tests, six of them driving the real `porter-native-host` binary and the registry service from simulated Chrome processes); `npm test` for `extensions/chrome` (25 tests, including validation of the messages the extension produces against the shared JSON Schemas); a smoke run of the release `porter-registryd`, relay and `porterctl` with two simulated profiles. The install and uninstall scripts were run against temporary directories only.
- Not verified: any real Chrome profile, the real `claude.ai` page title and URL behavior, loading the unpacked extension, Chrome launching the host, service-worker restarts, and whether `activate()` brings Chrome forward.
- Source: LOG-20261008-004.
- Tags: area/quality, area/browser, area/identity, phase/r0.
- Review trigger: the real two-profile run.

## FACT-014 — Real Chrome one-profile run

- Class: verified_test (observed by Prem on the reference Mac, 2026-10-08; Chrome 154.0.8037.98).
- Statement: with the unpacked extension in one Chrome profile, `porter-registryd` and the installed host manifest, a claude.ai chat tab at `https://claude.ai/chat/<uuid>` is reported to the registry with its title and tab and window IDs; two tabs of one chat are reported as two ambiguous routes; activating a route with another tab in front switched to that tab, and activating a route whose tab was closed and reopened was refused with `targetGone` and the reopened tab became a new route. Chrome found and launched the host from `NativeMessagingHosts/com.porter.bridge.json`.
- Also observed: two Chrome profiles register as two connectors; activating a route switches to the correct profile's window and tab in both directions; with a non-Chrome app in front, activation brought Chrome forward on the chosen chat (registry started from a terminal).
- TEST-001 (two profiles, identical titles, activation in both directions) observed passing in real Chrome.
- Navigating a tab to a different chat raised its route revision, and the earlier revision was refused with `targetChanged` (LOG-20261008-006).
- Chrome quit and relaunch: both profiles reconnected automatically, routes returned with new IDs, old IDs were refused (LOG-20261008-007).
- Not established: `connectorOffline` in real Chrome (routes vanish on quit), behavior when the registry runs inside the signed Mac app, and why the first listing showed 0 tabs.
- Source: LOG-20261008-005.
- Tags: area/browser, area/identity, phase/r1.
- Review trigger: the two-profile run.

## FACT-015 — Route ID continuity across a tab dropping out of the list

- Class: verified_test (unit tests plus one real-Chrome observation, 2026-10-08).
- Statement: a route keeps its ID and gains a higher revision when the same tab returns to the tab list showing the same chat; a different chat in the same tab number or a reconnect yields a new ID. In real Chrome a chat rename in one profile caused such a drop-out; its cause is not established. A click made against an older revision is refused with `targetChanged`, and against a missing route with `targetGone`.
- Source: LOG-20261008-006; `BridgeTests+Continuity.swift`.
- Tags: area/identity, area/browser, phase/r1.
- Review trigger: any change to how the extension builds tab lists, or an explanation of the drop-out.

## FACT-016 — Documented desktop chat links

- Class: source_documentation (accessed 2026-10-08); the app bundles were inspected locally.
- Statement: Claude desktop registers `claude` and documents `claude://claude.ai/chat/{conversation-id}` to open an existing chat; an invalid or missing ID opens the recent chats list, and no account rules are stated ([S12](../docs/SOURCES.md)). The installed `ChatGPT.app` is the Codex app (`com.openai.codex`); it documents `codex://threads/<thread-id>` for local threads only and nothing for ChatGPT web chats ([S09](../docs/SOURCES.md)). Neither app acknowledges a link opening, so Porter can request it but cannot confirm which chat or account appeared.
- Not tested: whether the installed Claude build honours the documented chat link, and which account it shows when the web chat belongs to another account.
- Tags: area/macos, area/identity, area/browser.
- Implication: resolves Q-005 for Claude as "documented, to be tested"; ChatGPT desktop targets are Codex threads, which are out of reach until a thread-listing source exists.

## FACT-017 — Mac panel, phone list and packet review are built but visually unreviewed

- Class: verified_test for the logic; no evidence for appearance or feel.
- Statement: the Mac app (`apps/macos`), phone app (`apps/ios`) and context packet review exist and pass their automated checks (LOG-20261008-008). The headless self test shows the real window and views construct and that window frames equal the computed geometry. It does not show how any of it looks. One iPhone screenshot of sample data showed the list rendering; a styling flaw (blue text from a default button style) found there was fixed and not re-photographed.
- Not established: glass appearance, transition feel, hit-testing of empty areas, Spaces and multi-display behavior, accessibility with real VoiceOver, real Chrome through the Mac app, the Claude desktop link on the installed build.
- Source: LOG-20261008-008.
- Tags: area/ux, area/macos, area/ios, phase/r1.
- Review trigger: the manual batch in docs/VALIDATION_RELEASE.md.

## FACT-018 — VS Code Claude Code chats are not visible to Porter and the documented link is weak

- Class: source_documentation (accessed 2026-10-08); local inspection of installed extensions.
- Statement: Porter's connector sees only browser tabs, so Claude Code conversations in VS Code do not appear. The documented `vscode://anthropic.claude-code/open?session=<id>` link resumes a session only if it belongs to the workspace of whichever VS Code window is focused, and otherwise silently starts a fresh conversation ([S13](../docs/SOURCES.md)). Nothing documented lists open sessions. Session IDs exist as file names under `~/.claude/projects/<project>/`, but their titles live inside the conversation files. Installed here: `anthropic.claude-code` and `openai.chatgpt` VS Code extensions.
- Implication: opening by this link can land on a new empty chat instead of the right one, which Porter must say before offering it. Listing sessions from files would need an explicit decision about reading metadata versus conversation text.
- Tags: area/macos, area/identity, area/security.
- Observed 2026-10-08 (LOG-20261008-011): in one VS Code 1.140 window the tab type is right and the position commands brought a Claude Code tab forward over a file tab. Tab titles may be truncated with an ellipsis, so a title alone is a weak identifier. An outside `vscode://` link to the probe also worked (twice, with a file tab in front) and moved keyboard focus to the chat input; VS Code showed a confirmation popup for the link, which Prem dismissed with its "don't show again" option (recurrence without it is unknown).

## FACT-019 — No account-level way to list sessions; hosts are known locally

- Class: source_documentation (accessed 2026-10-08) plus local inspection of names and structure only.
- Statement: Anthropic's terms forbid a third-party tool from offering Claude.ai login or collecting, storing or relaying Claude.ai credentials or session tokens ([S14](../docs/SOURCES.md)); no documented API lists claude.ai conversations or local Claude Code sessions, so an account-wide view is not available to Porter. A Claude Code session does know its host: its environment carries `CLAUDE_CODE_ENTRYPOINT` (here `claude-vscode`) and its session ID, and each VS Code window leaves a file under `~/.claude/ide/` naming the IDE, process ID and workspace folders next to a websocket auth token. Those files and `~/.claude/sessions/*.key` hold tokens, are undocumented internals, and about two thirds of the lock files seen were stale. Porter does not read them. The Claude Code editor tab is a webview of type `claudeVSCodePanel`, which the VS Code tab API can list.
- Implication: the VS Code route has to come from a companion extension using public VS Code APIs, not from Anthropic's account or from Claude Code's private files. Whether a specific tab can be brought forward externally is unproven and is measured by the probe.
- Tags: area/security, area/identity, area/macos.

## FACT-020 — VS Code tabs have no stable identity

- Class: verified_test for the derivation; the limits follow from VS Code's tab API.
- Statement: the tab API gives a label, position and whether the tab is active, with no ID that survives a rename, a reload or a move. The companion therefore derives an ID from the window's folder, the title and the order among same-titled tabs. Consequences: renaming a Claude Code chat makes a new route and strands a pin on the old one; two same-titled tabs swapping order swap identities; a truncated title is part of the identity. Activation re-checks position, title and that derived ID before acting, so a mismatch is refused, not guessed.
- Source: `extensions/vscode/src/identity.ts`, tests, LOG-20261008-012.
- Tags: area/identity, area/macos.
- Review trigger: if VS Code exposes a session ID for a tab, or Claude Code's extension offers one.

## FACT-021 — OpenAI (Codex) VS Code extension tab types

- Class: source inspection of the installed extension (`openai.chatgpt` 26.51002.51308), not runtime evidence.
- Statement: the extension contributes side-panel webview views (`chatgpt.sidebarView`, `chatgpt.sidebarSecondaryView`), which are not editor tabs and are invisible to the tab API; a webview panel type `chatgpt.panelView` created by "new Codex panel"; and a custom editor `chatgpt.conversationEditor` for `openai-codex:` resources. The companion matches the last two (provider `codex`). It is the Codex product, not the ChatGPT web app; the web app is a separate provider (`chatgpt`).
- Not established: that these are what a conversation tab really is at runtime, and what titles they carry. The diagnostic command exists to settle that.
- Tags: area/macos, area/identity.
- Review trigger: any Codex tab that Porter fails to list.

## FACT-022 — Agent working state comes from Claude Code hooks, only where it can be attributed

- Class: source_documentation ([S15](../docs/SOURCES.md)) plus automated tests; not yet observed in a live Claude Code session.
- Statement: Porter shows Working, Needs you and Idle for a Claude Code editor tab only when its registry has hook events from a session that was started from the VS Code extension (`CLAUDE_CODE_ENTRYPOINT` is `claude-vscode`), whose working folder is inside that window's folder, and when that window has exactly one Claude Code tab and exactly one such session. Anything else stays Unknown, including terminal sessions, windows with two Claude Code tabs, and every Codex and browser chat. Mapping: a prompt, tool call or tool result means working; a permission prompt, question or input request means needs you; a finish, session start or idle prompt means idle; a session end removes the status. A state lasts 30 minutes, then reads as "last seen"; a disconnected window reads the same way. The hook command keeps only the event name, session ID, folder, notification type and entrypoint; the prompt, tool input and transcript path are never copied, logged or sent (tested, including in error messages).
- Not established: that user-level hooks fire for the VS Code extension's sessions (the docs imply it), how long a real turn goes without a tool event, and how the status reads in daily use.
- Tags: area/identity, area/security, area/macos, phase/r1.
- Review trigger: the manual batch H, or Claude Code exposing a session ID per tab, which would remove the one-tab-per-window limit.
- Update (LOG-20261009-020): with several tabs in one window a session is now bound, at its first submitted prompt, to the tab that came to the front last in that window (the person typed there); the binding is kept for the session's life, and a tie, no times from the connector (a companion older than 0.2.0), or a start event alone bind nothing. Tested on synthetic windows only.
- Update (LOG-20261010-001): the ties are kept by the tab's connector-derived id, not the registry's per-run route id, and saved to `agent-bindings.json` in Porter's support folder (mode 600, ties older than a week dropped), so a restart of Porter no longer loses which tab a running session belongs to. Before this, every restart left running chats unbound, and with several tabs in a window they showed Unknown until their next prompt. `porterctl sessions` lists the sessions the registry knows and the tab each is tied to.

## FACT-023 — Panel motion is measured from its own frames

- Class: verified_test (on this Mac, three runs, 2026-10-08).
- Statement: the panel's opening is an explicit spring rendered per frame; `Porter --probe-animation` records the laid-out size of the glass shape on every frame and checks that it grows through several sizes, passes the pane width a little on the bounce and settles at it. It showed the earlier implicit-animation version jumping in one step. SwiftUI's `Animatable` modifier returning its content unchanged is never evaluated, and `CGWindowListCreateImage` is unavailable in this SDK, so `onGeometryChange` is the working measurement.
- Not established: how the glass itself looks mid-move, and the square outline's cause.
- Tags: area/macos, area/ux, phase/r1.
- Review trigger: any change to the panel's motion; rerun the probe.

## FACT-024 — Chrome and Safari can be read and driven without an extension; profiles cannot be told apart

- Class: verified_test (on this Mac, 2026-10-09; Apple Events from a terminal; Chrome with four windows open, Safari with one).
- Statement: Chrome's scripting interface lists every window and tab it has, including those of a second profile and an incognito window, with a per-tab `id`, `title` and `URL`, a per-window `id`, `mode` (normal or incognito) and `active tab index`, in about 0.2 to 0.35 s per query. Setting `active tab index`, then the window's `index` to 1, then `activate`, brought a chosen tab forward, including a tab in the second profile's window and back again; the check was Chrome's own report of its front window, not a look at the screen. No Chrome setting or extension was needed. Safari lists windows (with `id`) and tabs (name, URL, position; no tab id), and a tab was brought forward by window id and `current tab`.
- Pitfalls found: an incognito window is listed, so incognito must be excluded by default (`mode`). A window's `name` is only its active tab's title, with no profile label. Windows must be addressed by `window id`; looping with a window reference gave the wrong window after the order changed. Safari tabs have no id, so they are found by URL within a window.
- Profile (added after the Accessibility spike, FACT-025): the scripting interface has no profile property, but Chrome's accessibility window titles end with the profile name (\"... - Google Chrome - <profile>\", and \"(Incognito)\" for incognito), seen on three windows in one run. Pairing those windows with the scripted ones (by active tab title) was not tested.
- Not established: how to pair the two kinds of window reliably when two windows show the same title; last-used times (none exist; Porter could only record them from when it runs); whether the permission prompt names Porter once it runs as its own app (tests ran from a terminal that already had access); behavior with Chrome minimized, on another Space or full screen; Safari with several windows or profiles; whether Chrome accepts an externally installed extension (not part of this spike).
- Tags: area/browser, area/macos, phase/r1.
- Review trigger: a Chrome or Safari major update; the Accessibility spike (TASK-082) for profile identification.

## FACT-025 — The Claude and ChatGPT desktop apps can be read and driven through Accessibility

- Class: verified_test (on this Mac, 2026-10-09; a purpose-built helper app granted the Accessibility permission on its own; Claude desktop 2.31226.0 `com.anthropic.claudefordesktop`, and the OpenAI desktop app named "ChatGPT" 26.1002.52244 `com.openai.codex`; both Chromium-based).
- Statement: once the helper sets `AXManualAccessibility` on an app, its web interface appears in the accessibility tree within a few seconds (600 to 1000 elements). Window titles are only the app name, so the open conversation is not in the title. Reading controls in the left 300 points of the window (the sidebar) gives: in Claude, project groups, dated groups (Yesterday, dates, Older) and chat titles in recency order; in the ChatGPT app, projects, a Recents list with one button per chat, a per-chat "Unread" marker, and "Pin chat" buttons. Pressing a chat by its exact title (`AXPress` on the control or its nearest pressable parent) returned success in both apps and, as reported by Prem, opened that chat in each.
- Limits seen: no conversation identifier exists, only the title, so duplicate titles (several "Test" and "Untitled" chats) cannot be told apart except by position, and a renamed chat looks new; the accessibility windows list was empty in runs where the app was not in front (cause not isolated), so reading may need the app to be on the current desktop; the permission follows the app's code signature, so it must be re-granted after each rebuild during development; the first runs printed more than intended (Gmail rows, message links) because the filter was by control type, and only the position filter kept message content out.
- Not established: whether the app comes to the front on its own (Porter would activate it explicitly); stability across app updates (these are web interfaces and the labels are the apps' own); a working-state signal beyond "Unread"; reading with the app hidden or on another desktop; what the permission prompt looks like for the real Porter app.
- Tags: area/macos, area/browser, phase/r1.
- Review trigger: an update of either app; the real Porter app's first run; any change to how titles are exposed.

## FACT-026 — The VS Code companion installs from a command line, in VS Code, Cursor and Windsurf

- Class: verified_test (on this Mac, 2026-10-09; VS Code 1.140.0, Cursor 3.22.7, Windsurf 1.110.1; throwaway extension and user-data folders, so no real editor setup was touched).
- Statement: a `.vsix` built without a packaging tool (a zip with `[Content_Types].xml`, `extension.vsixmanifest` and an `extension/` folder; `extensions/vscode/scripts/package-vsix.sh`) was accepted by each editor's bundled command (`--install-extension`), listed by `--list-extensions`, and removed by `--uninstall-extension`. An install took under half a second and needed no editor window.
- Assessment of an Accessibility fallback for editors: not tried and not recommended for VS Code. Its window would expose the user's code to the tree, the companion already reports folder, provider and tab, and nothing would be gained for Claude Code or Codex tabs.
- Not established: that the companion then works inside Cursor or Windsurf (their agent extensions may name their tab types differently); how an already-running window picks up a command-line install (a reload is likely); installing into an editor's real extensions folder; JetBrains and Xcode (installed or not, not looked at).
- Tags: area/macos, area/release, phase/r1.
- Review trigger: an editor major update; adding a second editor family to the setup assistant.

## FACT-027 — Chrome installs an extension from a file the app provides, after one approval

- Class: verified_test (on this Mac, 2026-10-09; Chrome 154.0.8037.98 in a throwaway headless profile with its own user-data folder; one profile only).
- Statement: with `External Extensions/<id>.json` containing `{"external_crx": "<absolute path to a .crx>", "external_version": "0.1.0"}` in the profile's user-data folder, Chrome installed the packed Porter extension on first start with no Developer mode and no "Load unpacked". The extension appeared in the profile's secure preferences with location 2 (external) and `disable_reasons` 256, which is Chrome's "added by an external source, waiting for the user to enable it". The `.crx` must be signed with the key whose id the file is named after; Chrome's `--pack-extension` made one from a copy of the extension without the manifest `key`.
- Consequences: this is the route for "install the extension from the app", at the cost of one approval per profile. It needs the extension's private signing key to stay with the maintainer (never in the repository), and the extension id to follow from that key. The current manifest's `key` is public only, and no private key for it is kept, so a bundled `.crx` has a different id from the unpacked development extension.
- Chain check (`apps/macos/scripts/check-extension-install.sh`): the `.crx` that `build-app.sh` packs with a generated key, and the id derived from the manifest key inside the bundle, install together in a throwaway profile as location 2, disabled with reason 256, so the id, the key and the package agree.
- Not established: the approval prompt as a person sees it (the run was headless); whether a Chrome that is already running notices a new file without a restart; behavior with several profiles; Safari and other Chromium browsers.
- Tags: area/browser, area/release, phase/r1.
- Review trigger: a Chrome major update; the first run on a real profile.

## FACT-028 — Codex's thread list is a local file shared by VS Code, the app and the CLI

- Class: verified_test (on this Mac, 2026-10-09; Codex VS Code extension 26.930.51102, Codex desktop app 26.1002.52244; synthetic and live checks printing counts only).
- Statement: `~/.codex/session_index.jsonl` holds one JSON line per thread update (`id`, `thread_name`, `updated_at`); the same id can appear on many lines, and the latest is current. Each thread has a session file `sessions/YYYY/MM/DD/rollout-<time>-<id>.jsonl` whose first line is a `session_meta` record with `cwd` (the project folder), `originator` (`codex_vscode` for the VS Code extension, `Codex Desktop` or `codex_work_desktop` for the app), `source` and `parent_thread_id`. Of 76 indexed threads here, 51 were helper threads (`source.subagent`, with a parent), 19 came from VS Code and 5 from the app. The extension's link handler (`vscode://openai.chatgpt/<route>`) navigates its panel to the route, and `/local/<thread id>` is the thread route; the app registers the `codex` scheme and its code builds links of the form `codex://<route>`. The extension and the app therefore list the same threads, and VS Code's side panel, invisible to other extensions, does not hide them from this list.
- Used for: listing recent (7 days) user threads under their project, ordered by real update time, opened through those links after bringing the project's window forward.
- Not established: that `codex://local/<id>` opens a thread in the app (the form is inferred from the code, not tried); whether `vscode://` routes to the window just brought forward when several windows are open; what happens for a project folder with no open window; threads older than a week.
- Tags: area/macos, area/identity, phase/r1.
- Review trigger: a Codex update; the first real click on each kind of thread.

## FACT-029 — The glass edge shows only while the panel's window is active

- Class: reported by Prem on the running app (2026-10-09), not photographed or measured here.
- Statement: the Liquid Glass surface draws its edge only while its window is the active one. After the panel collapsed, the edge was missing until the panel was pressed, and it went again when another window took focus. Redrawing the glass, re-attaching the view and setting the SwiftUI active state (LOG-20261009-014 and earlier) did not change this. The panel is a non-activating window and is never active in the ordinary way, which is why it only appeared on a press.
- Response: the edge is drawn by Porter itself, a 1 pt stroke along the same rounded shape, so it no longer depends on the window state; the earlier workarounds were removed.
- Not established: how the stroke looks next to the system's own edge when the window is active (it may add to it), in light mode and with Reduce Transparency (which already drew its own border).
- Tags: area/macos, area/ux, phase/r1.
- Review trigger: a macOS update; Prem's look at it.

## FACT-030 — Liquid Glass follows the backdrop; a native menu does not

- Class: reported by Prem with a screenshot and a correction (2026-10-09), not measured here.
- Statement: in the dark appearance, over a white page, Porter's Liquid Glass capsule was a faint light shape and the hover label's white text was lost, while native menus (the Wispr Flow menu, the battery menu) stayed a mid-grey, readable surface. Prem's correction: native keeps its dark tone and does not lighten on a light background; Liquid Glass adapts to the backdrop's brightness, which is the opposite. The glass is also pale and edgeless because the panel's window is never the active one (FACT-029).
- First response (LOG-20261009-025), a tint of the window colour on the glass, kept the adaptive behaviour and was replaced.
- Response: the capsule, the pane and the label are now the system's menu material (`NSVisualEffectView`, material `.menu`, behind-window blending) forced to the active state, which follows the appearance and ignores the backdrop's brightness, like a menu. The cost is the glass's bending-light look. The 1 pt edge stays.
- Not established: how close `.menu` is to the menus on macOS 26 side by side; the material is one token (`Tokens.Surface.material`) if another (`.popover`, `.hudWindow`) is closer.
- Tags: area/macos, area/ux, phase/r1.
- Review trigger: Prem's comparison (batch O).

## FACT-031 — A hook can tell which terminal an agent runs in

- Class: verified_test for the process walk (synthetic process tables, and this process on the real kernel table); the AppleScript for Terminal and iTerm is written from their scripting dictionaries and has not been run against those applications.
- Statement: a Claude Code hook runs as the agent's descendant, so walking up its parent processes finds the terminal device (`ttys003`, from the first process with a controlling terminal) and the application that hosts it (the outermost `.app` on the path of an ancestor, then its bundle id from Info.plist). The hook adds both to its event for any session that did not start from VS Code's panel. The registry then lists those sessions as routes of their own (keyed by session id, with the project folder, the real time of the last event, the status, and a tab title when Terminal or iTerm can give one). Terminal and iTerm tabs are found again by their device; VS Code's integrated terminal needs only its window; other terminals (Ghostty, WezTerm, kitty, Warp, Alacritty, cmux) are listed with their status but cannot be brought forward by tab, and are reported as unsupported. A session whose hosting application is not on the known list is not listed.
- This Mac: the installed terminals are Terminal and cmux; no Claude Code session was running in a terminal when this was built, so nothing was seen end to end.
- Not established: the Terminal and iTerm scripts on the real applications (tty matching, selecting the tab, bringing the window forward, the title text Claude Code leaves in the tab), cmux's own way to select a workspace, and what a nested tmux or ssh session reports.
- Tags: area/macos, area/browser, phase/r1.
- Review trigger: the first terminal session on a real Mac; any terminal added to the list.

## Adding a fact

Include statement, evidence class, source/test reference, observed date, tags, and review trigger if volatile. A failed experiment can be a fact when its exact environment and outcome are recorded. Do not transform a plausible architectural assumption into a tested capability.
