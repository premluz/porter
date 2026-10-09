---
id: "DOC-VALIDATION"
type: "spec"
title: "Validation and release plan"
status: "draft"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/quality", "area/macos", "area/browser", "area/ios", "phase/r1", "phase/r2"]
summary: "Evidence requirements, test matrix, and release procedures."
related: ["DOC-SCOPE", "DOC-DATA", "DOC-SECURITY"]
---

# Validation and release

## Current implemented verification

From the project root, Python 3.10+:

```sh
python3 tools/project_memory.py index
python3 tools/project_memory.py check
python3 tools/test_project_memory.py
python3 tools/project_memory.py search "account" --tag area/identity
python3 tools/project_memory.py read DOC-STATE
```

These validate and retrieve documentation only.

Product contract and core checks (added 2026-10-08):

```sh
cd packages/contracts && npm ci && npm run validate
# expected: "9 schemas compiled, 29 fixtures behaved as expected"; invalid fixtures must fail
swift test --package-path packages/ConversationCore
# expected: all Swift Testing tests pass; fixture test decodes every valid contract fixture
cd packages/ConversationCore && xcodebuild -scheme ConversationCore -destination 'generic/platform=iOS Simulator' build
# expected: BUILD SUCCEEDED
```

```sh
swift test --package-path services/native-host
# expected: 13 tests pass; six launch the real porter-native-host binary from simulated Chrome processes
cd extensions/chrome && npm ci && npm test
# expected: 35 tests pass; one validates the messages the extension produces against packages/contracts schemas
cd extensions/chrome && npm run typecheck
services/native-host/scripts/install-dev.sh      # writes only the Chrome host manifest and the origin list
services/native-host/scripts/uninstall-dev.sh    # removes only those two files
```

Real two-profile check (TEST-001, TEST-002, TEST-011; requires a person at the Mac, so it is a procedure, not a pass/fail script):

1. Run `install-dev.sh`, then in each Chrome profile load `extensions/chrome` unpacked, confirm the printed extension ID, name the profile in the extension's Options, and click Allow access to claude.ai.
2. Open a disposable claude.ai chat in each profile and give both the same title.
3. Run `.build/release/porter-registryd`, then `.build/release/porterctl list`. Expect both profiles connected and two rows with different profile names.
4. Run `porterctl activate <id> <revision>` for each row and note which profile, window and tab comes forward, and whether Chrome itself comes to the front (`app:` in the output).
5. Negatives: close a tab then activate (targetGone); navigate a tab to another chat then activate with the old revision (targetChanged); quit Chrome then activate (connectorOffline); relaunch Chrome and confirm routes return with new IDs.
6. Record versions, results and surprises in PLAN-001 Discoveries. Use only disposable chats; do not paste chat contents into project memory.

Added later the same day (all pass; see LOG-20261008-008):

```sh
swift test --package-path packages/ConversationCore     # core, PorterStore, PorterPanelModel
swift test --package-path services/native-host
swift test --package-path apps/macos
cd extensions/vscode && npm ci && npm test      # 42 tests; also validates what it sends against the schemas
extensions/vscode/scripts/package-vsix.sh /tmp/porter.vsix --verify   # packs the companion and checks it installs into throwaway folders
cd apps/macos && swift build -c release && .build/release/Porter --self-test   # headless, shows no window
cd apps/ios && xcodebuild -project Porter.xcodeproj -scheme Porter -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
cd packages/contracts && node scripts/validate-messages.mjs <captured-messages.json>
```

No status adapter exists yet (status is Unknown everywhere); add its commands when it does.

## Manual test batch 2 (needs a person)

Everything above is automated. This batch covers what automation cannot: appearance, feel, real apps and accounts. Run it once, note only what differs from "Expect", and send that back. Use disposable chats. Build first: `cd apps/macos && swift build -c release`; the program is `apps/macos/.build/release/Porter`. Stop `porter-registryd` before running the live app (they share a socket).

**A. Mac panel with sample data** (`Porter --fixtures`; a menu-bar icon appears and a slim capsule at the right edge)
1. Expect a narrow glass capsule at the screen edge, no Dock icon, no focus taken from the app you were using. Menu-bar item: choose Left edge and back.
1b. Measured, not just looked at: `apps/macos/.build/release/Porter --probe-animation` opens the real panel once (it shows at the screen edge for about two seconds, so run it when you are not mid-click) and prints the width of the shape at every frame. Expect "distinct sizes between capsule and pane" of 4 or more, a peak a few points past 360 (the bounce), settling at 360, and no gap of more than ~20 ms between the first frames.
2. Press ⌃⌥Space. Expect the glass to morph from the capsule into the pane with one small overshoot and settle, then the search field and rows to fade in one after another (first ~8 rows). Search field focused; rows grouped Pinned (two) and Open. Look at: smoothness (the window is no longer resized frame by frame, so jitter should be gone), whether the bounce feels right or too much, corner shape during the move, readability over a bright window and a busy wallpaper. Scrollbar: it must not flash while opening, closing or resizing, and should appear only while you scroll (with a mouse wheel rather than a trackpad it may not appear at all; tell me if so).
3. Press ⌃⌥Space again part-way through opening, several times quickly. Expect it to reverse smoothly with no flash and no leftover window.
4. Type `release`: two rows both titled "Release plan", each showing its profile (Personal, Work). Clear with Esc (first Esc clears search; next closes).
4b. The Open list is ordered by recent use: Design review first (used seconds ago), then Release plan (Personal), Release plan (Work), Quarterly numbers, Design review (second tab shown within its row), Last week's draft last, and the chat with no recorded use after all dated ones. Pinned rows stay in your own order.
5. ↑/↓ then Return on each sample and note the message: Release plan (either) closes the pane; Design review is open in two tabs and asks which; its second tab says the tab was closed; Quarterly numbers says no answer and "may have opened"; Unlabelled chat says the tab shows something else; Last week's draft says the account changed. Pinned "Old research thread" offers recovery; "Archived notes" says Chrome is not connected.
6. ⌘P pins/unpins the selected row, ⌘⌫ hides it (a "Show n hidden" link appears), right-click shows the same plus "Open in Claude app". Relaunch: in fixture mode pins are not kept; in live mode they are.
7. Click a dot in the capsule: a single-tab chat opens directly; an ambiguous one opens the pane.
8. System Settings, Accessibility: turn on Reduce Motion (expect a fade or jump, no spring) then Reduce Transparency (expect an opaque pane). Turn both off again.
9. Click the desktop or another window while open: expect the pane to collapse. With the capsule showing, click the desktop right beside it: expect the click to reach the desktop.
10. If you have two displays or a full-screen app: invoke the shortcut over each; the capsule should be on the screen you used it from and stay usable.
11. VoiceOver (⌘F5): arrow through the rows; each should read title, provider, profile, status, and whether it is pinned or not open.

**B. Mac panel live, with real Chrome** (quit sample mode; run `Porter` with no flag; leave the Chrome extension from TEST-001 installed)
1. Expect your open Claude chats from both profiles, with profile names.
2. Return on one: Chrome comes forward on exactly that tab, the pane collapses. Repeat for the other profile.
3. Pin one, close its tab: it stays listed as "not open" with recovery. Reopen the chat: it returns as open and pinned.
4. Right-click a row, "Open in Claude app" (or ⌘O) with the Claude desktop app installed. Record: does it open that chat, which account does the app show, what if the chat belongs to the other account? Expect the footer to say Porter cannot see which account.
5. Quit Chrome: expect "browser not connected" on pins and an empty or reduced list. Reopen: routes return.

**C. Context packet**
1. Menu-bar icon, "Open context packet…", choose `packages/contracts/fixtures/valid/context-packet/atlas-capture-with-memento-sources.json`.
2. Expect a review: title, one current source checked, one stale source unchecked with a warning, character count, destination empty (its requested chat is not open) with a "Choose a different chat…" menu.
3. Press Copy, paste into TextEdit: expect the title, instruction, task and the single included source with its citation and revision, and nothing from the stale one. Nothing should have been sent or typed anywhere.
4. Tick the stale source: expect a warning that it is included. Choose a destination and press "Copy and open chat": expect the chat to open and the text to be on the clipboard.
5. Try a file that is not a packet: expect a refusal message and no review.

**D. iPhone app** (open `apps/ios/Porter.xcodeproj` in Xcode, run on an iPhone simulator)
1. Expect a "Sample data" banner, Pinned and Open sections, status in words, a dashed marker for anything not live. Tap a row: details sheet with a note that the account on the phone may differ and no open button (sample links go nowhere).
2. Settings, Accessibility, larger text at the maximum: expect no clipped rows. Rotate to landscape. Search for "release".

**L. One app that sets up the rest** (the bundled app; the setup window's install buttons).
1. `apps/macos/scripts/build-app.sh` builds `Porter.app` with its helpers, the VS Code companion (`porter-vscode.vsix`), the Chrome extension folder and the Claude Code hook installer inside it. Check: `codesign --verify --deep --strict apps/macos/.build/app/Porter.app` is silent, and `apps/macos/.build/app/Porter.app/Contents/MacOS/Porter --self-test` passes.
2. Open the bundle. In the setup window, **VS Code companion → Install in …** installs it in each found editor (VS Code, Cursor, Windsurf). Reload an editor window, then the row should turn ready within a few seconds. Tell me whether the companion works inside Cursor or Windsurf (untested).
3. **Claude Code status → Turn on…** asks first, then runs the bundled hook installer. Check `~/.claude/settings.json` gained Porter's hooks, that a dated backup exists next to it, and that your other settings are unchanged. Start a new Claude Code session to see Working and Needs you.
4. **Chrome extension → Set up…** registers the helper in the bundle with Chrome (this replaces the development registration that points into the repository) and writes the file that makes Chrome offer the bundled, signed extension. Quit Chrome completely and reopen it: it should offer to add or enable "Porter" in each profile; approve it in the ones you want. The row should then turn ready. Quit Porter and reopen: the extension must reconnect. The extension's id changes from the development one, because the bundled copy is signed with a key generated on this Mac (`~/.porter-signing/chrome-extension.pem`: back it up, never commit it). Without that file the id would differ on every machine. Automated check without touching your profiles: `apps/macos/scripts/check-extension-install.sh`.
5. **Open at login** turns on and off from the same window; macOS may ask you to approve it under System Settings → General → Login Items. `apps/macos/scripts/build-dmg.sh` makes `Porter.dmg` (drag Porter to Applications); open it and check both items are there.
6. Not covered yet: signing with a Developer ID, notarization (the script has the steps but they have not run), and updates. Everything above is signed ad hoc.

**K. Setup window** (the one place that says what works and what needs a permission).
1. Rebuild and restart the Mac app. On the very first launch it opens "Set up Porter"; later use the menu bar item **Set up Porter…**. To see the first-launch behavior again: `defaults delete <the app's domain> porter.setup.shown` (the domain is the executable's name, `Porter`), or just use the menu item.
2. Expect three lines under "Reads on its own" (Chrome, Claude app, ChatGPT app) and up to three under "Optional" (Chrome extension, VS Code companion, Claude Code status), each with a state icon. The summary line should match them (for example "1 of 3 ready; 1 needs your permission").
3. After changing any permission use **Restart Porter** in the window (macOS does not tell a running app that a permission changed). Refuse a permission on purpose (Automation for Chrome, or leave Accessibility off): the row must turn orange with a button. "Open Automation settings" opens that pane. "Allow Accessibility" shows the system prompt and opens the Accessibility pane; switch Porter on there, restart Porter, and the row should turn ready.
4. Quit Chrome or a desktop app: its row becomes "not open" with an **Open** button, never an error. Reopen it: the row turns ready within a few seconds without closing the window.
5. The window should list only what is attached: in sample-data mode (`Porter --fixtures`) it says there is nothing to set up.
6. Tell me anything unclear in the wording; the text is meant to be understood without this document.

**J. Claude and ChatGPT desktop apps** (FACT-025; read through Accessibility, no extension). Their sidebar chats appear in Porter and open from it.
1. Build and open the bundle as in batch I. macOS asks for Accessibility for Porter itself: use the setup window's **Allow Accessibility** button, switch **Porter** on in the pane that opens, then quit and reopen Porter (a running process does not notice the change). The build is signed ad hoc, so each rebuild is a new identity to macOS and the permission has to be granted again; a Developer ID signature fixes that.
2. Open the Claude app and the ChatGPT app with their sidebars showing, on the desktop you are on. Within a few seconds their chats should be listed, with the app's own order (newest first) and no profile name. The panel groups recent chats under the day they were last used (Today, Yesterday, 2 days ago, then dates), like the Claude app does; Claude app chats take their day from the app's own headings. The ChatGPT app shows no dates, so its chats sit under "Open" (open, time unknown), as do browser tabs Porter has not yet seen in front.
3. Click a chat: that chat must open in its app and the app must come forward. Try a chat whose title is shared by another (several "Test" or "Untitled"): it must open the one you clicked, or say it changed, never silently the wrong one. Tell me what you see.
4. Rename or delete a chat in the app, then click its old row: expect "gone" or "changed", not another chat.
5. Collapse the sidebar: the list should stay as it was, not empty out, and the problem should show in Porter's log (stderr). Hide the app or move it to another desktop: same.
6. In the ChatGPT app a chat with unread replies is marked; Porter does not show that yet (it is not a verified status). Tell me if the list is missing chats that the sidebar shows (for example pinned ones or older groups).
7. Without the permission: nothing is listed and nothing explains why yet (the setup screen, TASK-084, will).
8. Automated check against the real apps (counts only; needs the permission for the test process): `PORTER_LIVE_APPS=1 swift test --package-path services/native-host --filter LiveDesktopTests`.

**I. Chrome without the extension** (FACT-024; the app reads Chrome itself). Chrome tabs on claude.ai and chatgpt.com appear with no extension and no profile name.
1. Build and open the app bundle: `apps/macos/scripts/build-app.sh && open apps/macos/.build/app/Porter.app` (quit any running Porter first). To see the no-extension result clearly, switch the Porter extension off in `chrome://extensions` (or compare with it on).
2. Open two Claude chats, one of them in a second profile's window. Open the panel: both should be listed within a couple of seconds, with the profile shown as unknown.
3. The first time, macOS asks whether Porter (or the terminal you started it from) may control Chrome. Allow it. If you refuse, nothing is listed and nothing explains why yet (the setup screen, TASK-084, will); tell me what you see.
4. Click each chat: Chrome must come forward on exactly that tab, in the right window. Rename a chat or navigate away and click the old row: expect a clear "changed" or "gone" message, not the wrong tab.
5. Open a chat in an incognito window: it must not appear. Open a non-chat page on claude.ai (settings, the home page): it must not appear.
6. With the extension on as well: each chat should appear once, through the extension. A chat open only in a profile without the extension still appears through scripting.
7. Quit Chrome: the chats should show as unavailable, and Chrome must not be relaunched by Porter.
8. Automated check against the real Chrome, printing counts only: `PORTER_LIVE_CHROME=1 swift test --package-path services/native-host --filter LiveChromeTests`.

**H. Agent working state (Claude Code hooks).** Shows Working, Needs you and Idle on a Claude Code tab. It changes your Claude settings, so it is a deliberate step.
1. Build: `swift build -c release --package-path services/native-host` and rebuild the Mac app; restart the Mac app.
2. Quick check without Claude: with the app running and a VS Code window open on `/path/to/folder` with exactly one Claude Code tab, run `echo '{"session_id":"t1","cwd":"/path/to/folder","hook_event_name":"UserPromptSubmit"}' | CLAUDE_CODE_ENTRYPOINT=claude-vscode /Users/przemek/Porter/services/native-host/.build/release/porterctl hook`. Open the pane: that tab should show a pulsing ring and "Working". Send the same with `"hook_event_name":"Stop"`: "Idle". With `"Notification"` plus `"notification_type":"permission_prompt"`: "Needs you". The command must print nothing and exit 0 each time (`echo $?`).
3. See what would change in your settings: `services/native-host/scripts/claude-hooks.sh`. It changes nothing without `--apply`. Then `claude-hooks.sh --apply` (it backs up `~/.claude/settings.json` first and keeps your other settings and hooks). To undo: `claude-hooks.sh --remove`.
4. Start a new Claude Code conversation (or reload the VS Code window) so it reads the hooks, then run `/hooks` in Claude Code to confirm Porter's hooks are listed.
5. In a window with exactly one Claude Code tab, send a prompt. Expect "Working" while it runs, "Needs you" if it asks for permission, then "Idle" when it finishes. Then open a second Claude Code tab in the same window: status must go back to Unknown (it cannot tell which tab). Run `claude` in a terminal in that folder: it must not change the VS Code tab's status.
6. If nothing ever changes in step 5 but step 2 worked, the extension's sessions are not firing user-level hooks; tell me.
7. Test the install script itself any time with `services/native-host/scripts/test-claude-hooks.sh` (uses a temporary file only).

**E0. Recency (live).** Open three Claude chats in Chrome and, in VS Code, two Claude Code tabs. Click through them in a known order, then open the pane. Expect the one you used last on top, and the order to follow as you switch (click away and reopen the pane). Quirks to report: a chat you only returned to by switching windows should also rise; tabs nobody has focused since the window opened sit below those that were; the list must not reshuffle while the pane is open.

**E. Other provider and diagnostics**
1. In Chrome, reload the extension (chrome://extensions, the reload arrow on Porter), then open its Options: Claude and ChatGPT are listed; ChatGPT is marked untested. Allow ChatGPT, open a `chatgpt.com` chat, and record whether it appears with a sensible title and activates correctly. If it does not appear, open the extension's service worker console (chrome://extensions, "service worker" link) and copy any line starting `[porter] tab on an allowed site was not recognised`; it shows the address shape (identifiers hidden), which is what I need to fix the adapter. Remove the permission afterwards if you prefer.
2. Rename a Claude chat. In `chrome://extensions`, open Porter's service worker console: if the tab drops out of the list, a `[porter] tab N left the list but still exists` line appears with the page status and an address shape. Copy it to me (it contains no chat ID).

**F. VS Code companion** (VS Code 1.94 or later; you have 1.140). It replaces the earlier probe, which this step unlinks automatically.
1. `/Users/przemek/Porter/extensions/vscode/scripts/link-dev.sh link`, then run "Developer: Reload Window" in each VS Code window. Expect a "Porter" item in the status bar (bottom right): "not connected" until the Mac app runs.
2. Start the live Mac app (`apps/macos/.build/release/Porter`, after `swift build -c release`; stop `porter-registryd` first). Within about 30 seconds each VS Code window's status bar should say "Porter connected", and its tooltip should say how many Claude Code tabs it reports.
3. Open the pane (⌃⌥Space). Expect each open Claude Code tab as a row labelled "Claude Code · <folder name>", next to your Chrome chats. Two windows with same-titled tabs must show two rows with different folder names.
4. In VS Code, put a **file tab** in front in window A. With another app in front, choose window A's Claude Code row in the pane and press Return. Expect: VS Code comes forward, window A is the one in front, its Claude Code tab is selected, the pane closes. Note any delay or flicker. (The Mac app opens the window's folder first, then asks the window to select the tab.)
5. Repeat with window B in front when you choose a row from window A. Expect window A to come forward, not a new window.
6. Close the tab, choose its (now stale) pinned row: expect a message about the VS Code window, not Chrome. Quit VS Code: expect "VS Code is not connected" with an "Open VS Code" button.
7. Rename a Claude Code chat: expect the old row to disappear and a new one to appear (a known limit, see FACT-020). If you had pinned the old one it stays as a closed pin.
8. Reload the VS Code window: the status bar should reconnect by itself. Command Palette: "Porter: Show connection status" and "Porter: List Claude Code tabs in this window".
9. **ChatGPT (Codex) in VS Code.** The OpenAI extension shows its conversations either in its side panel (not visible to Porter) or as editor tabs (visible). Open one as an editor tab ("Codex: new panel", or open a conversation in the editor area). Expect a row labelled "ChatGPT Codex · <folder>" and the same bring-forward behaviour as Claude Code. If it does not appear, run "Porter: Describe all tabs in this window (diagnostic)" and paste the line for that tab: it shows the tab kind and view type, which is exactly what the matcher needs.
10. To remove: `link-dev.sh unlink`, reload windows.

Record, for each step that differs: what you saw, macOS and Chrome versions, and whether it was dark or light mode.

## Testing strategy

Keep the status reducer, identity matching, protocol validation, and preference merge in deterministic unit tests. Use DOM fixtures with representative streaming, idle, pending-question, navigation, logout, and layout-change states for each adapter. Use live integration tests for actual browser/native focus and real-device tests for mobile behavior. A mock cannot prove cross-profile activation, permissions, code signing, background sync, or glass behavior.

## Acceptance matrix

| Test ID | Scenario | Expected result | Requirements |
| --- | --- | --- | --- |
| TEST-001 | Two profiles, identical chat titles, multiple windows | Intended tab and window activated; no cross-profile confusion | REQ-004, REQ-005, REQ-006 |
| TEST-002 | Close/move/navigate target after selection | Current locator resolved or typed failure; no wrong tab activation | REQ-004 |
| TEST-003 | Sign out/change provider account | Previous identity invalidated or capability limited; no false account assertion | REQ-006 |
| TEST-004 | Disconnect browser, freeze/discard tab | Stale/unknown visible with age; no completed-task claim | REQ-007 |
| TEST-005 | Restart browser with changed tab IDs | Snapshot reconciles; old locators not reused as identities | REQ-010 |
| TEST-006 | Adapter selector no longer matches | Navigation retained if valid; status becomes unknown | REQ-007 |
| TEST-007 | Fresh response then source/source-view acknowledgment | Unread behavior follows evidence and local acknowledgment rules | REQ-007 |
| TEST-008 | Multiple displays, full-screen Space, Dock edges | Panel remains accessible, bounded, and correctly positioned | REQ-001 |
| TEST-009 | Open, reverse mid-transition, reduce motion/transparency | No flash, stale hit region, stretched text, or inaccessible control | REQ-001, REQ-008 |
| TEST-010 | VoiceOver and keyboard-only navigation | All core actions and status meanings available | REQ-008 |
| TEST-011 | Malformed IPC, forged source, unknown version | Rejected safely; existing registry remains usable | REQ-012 |
| TEST-012 | Uninstall/disable extension and deny optional permissions | Explain reduced functionality; no repeated permission loop | REQ-011, REQ-012 |
| TEST-013 | Native deep link with correct/wrong account | Correct chat where supported; limitation surfaced where not | REQ-009 |
| TEST-014 | Phone refresh, Mac asleep, network unavailable | Cached list with last update; no live status claim | REQ-013 |
| TEST-015 | Phone has different provider account | Original app owns login; no silent account substitution | REQ-014 |
| TEST-016 | Revoke device, delete source, delayed old update | Revocation/tombstone policy holds; old data cannot resurrect | REQ-015 |
| TEST-017 | Preview off/on/off, expired excerpt | No collection when off; cache deletion verified | REQ-016 |
| TEST-018 | Send wrong revision, acknowledgment loss, duplicate request | Reject changed target; uncertain outcome remains uncertain | REQ-017 |
| TEST-019 | Summary source changes or contains injected instructions | Invalidate old summary; source text cannot trigger actions | REQ-018 |
| TEST-020 | New agent starts with this folder only | Finds current task, constraints, decisions, and actual evidence | REQ-019 |
| TEST-021 | Future MCP tries path traversal/write through read tools | Access confined to allowlisted docs; read tools cannot mutate | REQ-020 |

## Compatibility evidence format

For each integration record exact OS version, app/browser version, extension/adapter version, account/profile setup using non-sensitive labels, tested capabilities, date, test IDs, and result. Label unsupported and not-tested separately. Do not claim “supports ChatGPT desktop” based solely on a working web link or provider SDK.

## Proposed build verification after scaffold

Native core: `swift test --package-path packages/ConversationCore` after that package exists. Mac app: use `xcodebuild -list` to discover the real project/scheme, then record the actual build/test invocation. Extension: create and document real package scripts for typecheck, unit tests, and bundling; do not run fictional npm scripts. iPhone: simulator layout/unit tests plus a physical device for cloud sign-in, mobile links, and background behavior.

Continuous integration can validate docs, protocol fixtures, core logic, and extension tests. macOS runners are required for native builds. Physical-device/manual evidence remains part of R2 readiness.

## R1 release gate

- All P0 R1 task acceptance criteria and TEST-001 through TEST-013 pass or an explicit scope limitation removes the affected claim.
- No unresolved wrong-destination defect.
- Packaging validated on a clean user account, including native helper registration and browser extension onboarding.
- Measured performance budgets and accessibility review captured.
- Signing/notarization verified with the actual distribution artifact.
- Adapter compatibility table, limitations, and privacy text match tested behavior.
- Update/rollback paths documented and checked before automatic updates are offered.

## R2 release gate

R1 gate plus TEST-014 through TEST-016 on a physical iPhone, selected sync transport verification, cloud sign-out/deletion behavior, clear last-updated UX, and TestFlight install validation. Background refresh is best effort; foreground convergence is the defined baseline unless stronger delivery evidence is obtained.

## Release record and rollback

Record version, source commit, toolchain, supported OS versions, adapter versions, artifact checksum, test evidence, migrations, known limitations, and rollback instructions. Source can be rolled back independently only when data migrations remain compatible. Back up test fixtures before migration tests; never claim downgrading a database is automatically safe.

## Evidence hygiene

Store reproducible steps and sanitized excerpts. Screenshots may contain private chat titles; use fixtures or redact them. Do not store credentials or source chat content in logs. Mark not-run checks explicitly and name the environment limitation.
