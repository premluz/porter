---
id: "DOC-FACTS"
type: "memory"
title: "Durable project facts"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/memory", "area/product", "phase/foundation"]
summary: "User requirements and established findings with evidence classification."
related: ["DOC-CONSTITUTION", "DOC-SOURCES", "DOC-QUESTIONS"]
---

# Durable facts

Evidence classes: `user_requirement`, `source_documentation`, `verified_test`. Proposed implementation choices belong in ADRs/questions, not as verified facts. User evidence below is the current project conversation on 2026-10-08; no external transcript is required to interpret the recorded requirement.

Earlier records [FACT-001 to FACT-020](facts/FOUNDATION.md) retain their original IDs and evidence.

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
- Update (LOG-20261010-010): Codex threads are the exception to "every Codex chat stays Unknown": their working state is read from the thread's session file (FACT-034). Browser chats, the Claude and ChatGPT desktop apps' own chats, and Needs you for Codex remain Unknown.
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

## FACT-032 — The panel's resting states are decided by pure functions; their feel is not established

- Class: verified_test for the geometry and the drag decisions (`DockModelTests`, `DockDragTests`, `PanelLayoutTests`, the self-test windows); unverified for how it looks and feels.
- Statement: where the panel rests (docked tab or floating capsule, standing or lying down), the pull towards an edge while dragging, when a drag detaches a docked tab, when a release docks, and the window that always contains both the resting shape and its flares are computed by pure functions of the screen, the pointer and the dot count, and the same numbers drive the self-test's window checks. The thresholds (snap 56 pt, pull 96 pt, detach 28 pt, reflow slack 24 pt, peek grace 450 ms, click guard 0.25 s) are tokens chosen by reasoning, not by trying them.
- Not established: whether those thresholds feel right with a real pointer, how the flared tab reads on light and dark backdrops, whether a click right after a drag is reliably ignored, whether the pointer tracking that opens the peek behaves across Spaces and displays, and what a screen change (display unplugged) does to a remembered floating position beyond keeping it on the visible frame.
- Tags: area/macos, area/ux, phase/r1.
- Review trigger: batch R in docs/VALIDATION_RELEASE.md; any change to a dock token.

## FACT-033 — Tracing the liquid outline costs under a millisecond in release

- Class: verified_test (a timing run over 21 frames of a docked tab opening into a 360 × 520 pt pane, on this Mac, Apple silicon, 2026-10-10; the timing test was removed after the run).
- Statement: the slowest single trace of the fused outline took 0.71 ms in a release build and 14.4 ms in a debug build. SwiftUI traces it twice per frame (clip and edge line), so about 1.4 ms per frame in release. The release animation probe still renders 23 distinct sizes on the open; the debug one renders 7.
- Not established: cost on Intel or older Apple silicon, at larger panes, or with several displays at high refresh rates.
- Tags: area/macos, area/ux, phase/r1.
- Review trigger: any change to `Tokens.Liquid` or the pane size; a report of stutter on another Mac.

## FACT-034 — A Codex thread's open turn can be read from its session file, by record type

- Class: verified_test (synthetic files, and this Mac's real `~/.codex` on 2026-10-10: the thread being worked in was reported working while its file was being written; record types and counts only, no content read).
- Statement: Codex's session file for each thread gets a `task_started` record when a turn begins and a `task_complete` or `turn_aborted` record when it ends (event records, `"type":"event_msg","payload":{"type":…}`). Across four days of this Mac's sessions there were 1150 starts, 1134 completes and 15 aborts, so every turn ends one of those two ways; the remaining start was the live turn. A thread is working when its last start is after its last end and its file was written within the last 120 seconds. The silence limit stands in for a Codex that was killed mid-turn, which leaves the turn open for good. Records can be megabytes (one here was 5 MB), so Porter finds the markers as raw bytes in the last 16 MB, never decoding a record; the unescaped structural prefix cannot occur inside a message because its quotes are escaped (tested). The thread's connector reports the claim again every 15 seconds while it holds, and the registry lets it lapse after 45 seconds without a repeat.
- Applies to: every Codex thread, whichever surface made it (VS Code extension, desktop app, CLI), because they share the session files. Only "working" is claimed from this; a thread with no open turn has no status, not Idle.
- Not established: whether a long tool call with no output for over 2 minutes is common (it reads as not working until the file is written again; the limit is a guess), whether a turn waiting on an approval is distinguishable (no approval record type was seen in four days, so Needs you is not offered for Codex), how the desktop app's own chats (not Codex threads) and Claude's desktop app could be read (no signal identified yet), and behaviour for a turn over 16 MB.
- Tags: area/macos, area/identity, phase/r1.
- Review trigger: a Codex update that changes its record types; the first report of a wrong or missing Working on a Codex thread.

## FACT-035 — Turn completion is separate evidence, carried through status

- Class: verified_test and local_observation (2026-10-10).
- Statement: Claude Code Stop records a completed turn end; SessionEnd and lapse
  do not. Codex end-marker timestamps/kinds survive through app reports, registry
  destinations and panel items. Positive recent end evidence supplies Idle;
  withdrawal alone supplies no end. This supersedes FACT-034's working-only exposure.
- Evidence: TurnEndTests, CodexTurnEndTests, CompletionDetectorTests and
  CompletionNoticeTests and TurnEndProjectionTests; `tools/check_codex_turn_headers.py`. Real scans found
  VS Code headers both with ordinal (147 sessions) and without (2), and 50,048
  other-surface ordinal headers; no message text or titles were printed.
- Limits: loss of observation suppresses announcements; actual notice delivery
  and lock-transition timing remain batch U.
- Tags: area/macos, area/identity, phase/r1. Review trigger: source format change.

## FACT-036 — On-device speech API availability does not establish voice accuracy

- Class: local_observation and verified_test (2026-10-10).
- Statement: on this macOS 26.6.2 Mac, the unsandboxed legacy recognizer reports
  on-device support for en-US but not en-GB. SpeechTranscriber supports both;
  its model assets are absent. Speech authorization was not determined and
  microphone authorization already allowed. No permission or download was requested.
- Evidence: [recognition harness](../spikes/voice-recognition/README.md), four
  corpus/metrics tests, release bundle/plist/signature checks and read-only probes.
- Limits: sandbox probes returned misleading denial/unavailability. No real voice
  corpus, live latency, recognizer-service CPU, energy or wake reliability evidence
  exists here; TASK-093 incomplete and wake phrase no-go pending measurement.
- Tags: area/macos, area/security, phase/r1. Review trigger: OS, locale or model change.

## Adding a fact

Include statement, evidence class, source/test reference, observed date, tags, and review trigger if volatile. A failed experiment can be a fact when its exact environment and outcome are recorded. Do not transform a plausible architectural assumption into a tested capability.
