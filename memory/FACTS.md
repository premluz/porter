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

## Adding a fact

Include statement, evidence class, source/test reference, observed date, tags, and review trigger if volatile. A failed experiment can be a fact when its exact environment and outcome are recorded. Do not transform a plausible architectural assumption into a tested capability.
