---
id: "DOC-VALIDATION-MANUAL"
type: "spec"
title: "Existing manual validation batches"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/memory", "phase/r1"]
summary: "Preserved records split to keep documents under 200 lines."
related: ["DOC-STATE"]
---

# Existing manual validation batches

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

**T. Find the working signal in the desktop apps** (one-off, needs you; the probe prints button labels only).
1. Quit and reopen the rebuilt Porter, then in Setup use **Allow Accessibility**, switch **Porter** on, and quit and reopen Porter once more.
2. In the ChatGPT app (not Codex) open a chat and send a prompt that takes a while to answer. While it is writing, run in Terminal: `open -n /Users/przemek/Porter/apps/macos/.build/app/Porter.app --stdout /tmp/porter-probe.txt --stderr /tmp/porter-probe.txt --args --probe-controls com.openai.codex 40`, wait 45 seconds, and send me `/tmp/porter-probe.txt`. The reply should be still being written for the first part of the 40 seconds and finished for the rest, so the Stop control comes and goes. Keep the app's window in front on the chat.
3. Same in the Claude app: `... --probe-controls com.anthropic.claudefordesktop 40`, with a Claude chat answering.
4. Same for a Codex turn in the ChatGPT app (bundle `com.openai.codex`), to see what it shows while a turn runs and whether an approval prompt adds a control.

**S. Working status for Codex** (FACT-034; Codex threads only, not the desktop apps' own chats).
1. Rebuild and restart Porter. Ask Codex (VS Code or the ChatGPT app) for something that takes a minute or two.
2. Within about 5 seconds its row should show the working mark (green ring), and the docked tab, if docked, should show it too. When Codex finishes the mark should clear within about 5 seconds (it lapses, it does not turn to Idle).
3. Interrupt a turn (stop it): the mark clears. Quit Codex in the middle of a turn: the mark clears within about 2 minutes, never stays.
4. Give Codex a long command (a build or test run over 2 minutes with no output): tell me if the mark drops out mid-run and comes back, so the 120 second limit can be tuned.
5. Chats in the ChatGPT or Claude desktop apps (not Codex) still show no working status; that is expected for now.

**R. Moving the panel: docked, floating, open** (FACT-032; PLAN-003).
1. Rebuild and restart Porter. It starts as it was: a capsule at the edge you had. Hover it: nothing changes yet if it is a capsule (only a docked tab peeks).
2. Drag the capsule by a dot towards the middle of the screen: it follows the pointer at once. Release in open space: it stays there as a floating capsule. Quit and reopen: it is still there.
3. Drag it toward the right edge. Within about 100 pt it should lean towards the edge, and releasing within about 56 pt of the edge should fold it into a small tab flush with the edge, solid black like a camera cut-out, flaring into it with smooth concave curves and no outline or inner line at all, in one liquid motion (no jump, no second window). Just before it joins, the edge should visibly reach out to the capsule (a neck), never show a gap. Judge this only in the release build (`Porter.app`); a debug build drops frames. The glass should turn black as it folds in, and back to glass when it opens or peeks. Check it on a light page too. Do the same on the left. The tab is one small round face with two eyes looking towards the middle of the screen, coloured for all the chats together: orange if any chat is waiting on you, otherwise green if any is working, otherwise gray (with several chats, check that a question wins over work, and that it changes as they change; tell me if it reads as friendly, odd or too small). If it ever looks blank, tell me which Porter is running (quit all and reopen the rebuilt one).
4. Hover the tab: the capsule grows out of it. Move away: after about half a second it folds back. Moving from the tab to the capsule must not make it fold in between. Click a dot while peeking: that chat opens as before.
5. Drag a docked tab (or the peek capsule) away from the edge: it detaches as a standing capsule under the pointer. A small drag that never leaves the edge should not move it.
6. Drag a floating capsule near the top or bottom of the screen: the dots lie down into a row. Drag it back to the middle: they stand up again. Try it with a few chats and with many (the row is longer). It must not flicker between the two when you hold it near the limit.
7. Open the pane from each place (docked tab click, peek, floating capsule): the pane opens at the edge from a docked one and at the capsule's place from a floating one, kept on the screen, and closing returns to where it was. Esc and clicking elsewhere still close it.
8. A click straight after a drag must not open a chat. Menu bar item, Left edge or Right edge: docks it there.
9. Tell me which of these looks or feels wrong: the thresholds (pull, snap, grace) are guesses, the flare shape and the morph have never been seen.

**Q. Agents in terminals** (FACT-031).
1. Turn on Claude Code status (batch H; it applies to every Claude Code session, terminal ones included) and rebuild and open the app.
2. In Terminal, run `claude` in a project folder and send a prompt. Within a few seconds a route appears: `(logo) [Folder] Terminal · Working`, titled with the tab's title (or "Claude Code in <folder>"), in today's group. It goes Idle when the answer finishes, and Needs you with a notice if it asks for permission (batch P).
3. Click it: Terminal should come to the front on that tab, in the right window, even with several windows and tabs. The first time macOS asks to let Porter control Terminal; allow it. Tell me whether the right tab is selected and what the list shows as the title.
4. Repeat in iTerm if you use it, and in VS Code's integrated terminal (clicking brings the right window forward; the terminal panel itself is not focused). Other terminals (cmux, Ghostty, Warp) should be listed with their status but report "This can't be opened from here" on click; tell me which ones you use so the most common can be made to work.
5. `porterctl sessions` lists these sessions too. Setup shows an **Agents in terminals** row with the count.

**P. Needs you** (a chat waiting on you comes first, with a notice on this Mac; nothing is sent anywhere).
1. Rebuild and open the app. In Setup, **Notifications → Allow notifications** and choose Allow in the system prompt (it only appears for the bundled app).
2. With Claude Code status on (batch H), in a VS Code window whose chat Porter can tie to its tab, ask Claude Code to do something that needs permission (a command it must ask about). Within a few seconds that chat moves to a **Needs you** section at the top of the pane, the capsule's first dot shows the attention mark, and a notice "<Project> needs you / <chat title>" appears. Clicking the notice opens Porter's pane.
3. Answer in VS Code: the chat leaves the section and the notice disappears. Ask something that needs you again: a new notice. Repeated refreshes never repeat a notice, and with the pane open you get no notice.
4. Only a fresh signal counts: a chat that needed you half an hour ago and went quiet is not promoted. Status exists only where Porter has hook events (Claude Code in VS Code for now), so browser and desktop-app chats never appear here yet. Tell me what you see.

**O. Collapsed capsule: label on hover, the hand, and the edge** (FACT-029).
1. Rebuild and open the app. With the panel collapsed, move the pointer onto a dot: its label appears at once (a quick, soft grow out of the capsule's side), beside the capsule on the side facing the screen, level with the dot, with the chat's title and the same line a row has. Sweep down the dots: the one label glides to follow, and does not blink out between dots. Leave the last dot or the capsule: it eases away. It must never take the pointer or focus, and it must not appear while the pane is open.
2. The dot under the pointer lights up and swells a little, and the cursor is the pointing hand over every dot and over the open button (the arrow elsewhere). Click a dot: it takes you to that chat.
3. The capsule shows a thin edge all the time: right after collapsing, with no click, and when another app's window has focus. Compare with the system's own edge (press the capsule): tell me if the two look doubled.
3b. Colour against the system: put the capsule, the open pane and a hover label over a white page, over a dark one, and over a mixed one (a photo), in the dark and the light appearance, and compare each with a native menu or the battery menu open at the same time. The surface is the menu material now: it should keep the appearance's tone (dark in dark, light in light) and not lighten or darken with the page, with readable text. Tell me how it differs (too light, too dark, too grey, too blurry); `Tokens.Surface.material` can be switched to another system material.
4. Open the pane: the row under the pointer takes a very light tint (lighter than the keyboard selection) and the cursor is the pointing hand over rows; over the search field it stays the text cursor, and over the header and footer the arrow. Scroll a long list under a still pointer, then move a little: the tint follows the row that is under it, never one hidden under the search field. The hover is subtle on purpose; tell me if it is still too strong or too faint, on dots or on rows.
5. With Reduce Motion on, the label fades quickly without the grow or the glide. Tell me if any dot never shows a label, or if the hand is slow to appear (an inactive window's cursor is the least certain part).

**N. Codex threads** (from Codex's own thread list; VS Code chats and Codex-app chats together).
1. Rebuild and open the app. Setup shows a **Codex threads** row (only if `~/.codex` exists). Within a few seconds recent Codex threads (last 7 days, no helper threads) are listed under their project: `[Atlas] (logo) …`. Codex tabs from VS Code windows are no longer listed separately (the thread list covers them; no companion reload is needed for that).
2. Click a Codex thread that was made in VS Code: its project's window should come forward and the thread should open in the Codex panel. With several windows open, check it is the right one; tell me if it opens in the wrong window or nothing happens.
3. Click a thread that was made in the Codex app (the **ChatGPT** app here): the app should open that thread. This uses `codex://local/<id>`, inferred from the app's code and not tried; tell me what happens.
4. Rename a thread in Codex, then click its old row before the list refreshes: expect "changed", not another thread. Archive or delete one: it should disappear within seconds.
5. Compare with the `~/.codex` truth without printing it: `PORTER_LIVE_CODEX=1 swift test --package-path services/native-host --filter LiveCodexTests` prints how many threads and projects it found.

**M. Row detail line** (assistant logo, project pill, source, status). Each row's second line reads like `(logo) [Amble] VS Code · Idle`; the source is Browser, VS Code or App, and a Codex thread made in the Codex app says App.
1. Rebuild and open the app. A Claude Code or Codex chat in a VS Code window shows the Claude or ChatGPT logo, then the window's folder as a rounded pill, then the status. A browser chat has no pill: the logo, the status, then the Chrome profile (`Unknown · Prem`) so identical titles stay distinguishable. Desktop-app chats show the logo and the status.
2. The logo is the icon of the Claude app or the ChatGPT app installed on this Mac; without that app a plain sparkle stands in. Hover it for the product name (Claude Code versus Claude, Codex versus ChatGPT are told apart there, and in VoiceOver).
3. Opening a chat from Porter must not lift it to the top: click an old chat, then look at the list; it stays where it was (the order follows the last time you used a chat, not the click). Chats with an agent's own signal (Claude Code with status on, Codex threads) are ordered by their last interaction; browser chats and Claude Code tabs without a signal by when they last came to the front. Long folder names are cut at a width; check one. Check the selected row and Dark mode. Tell me what looks off.

**L. One app that sets up the rest** (the bundled app; the setup window's install buttons).
1. `apps/macos/scripts/build-app.sh` builds `Porter.app` with its helpers, the VS Code companion (`porter-vscode.vsix`), the Chrome extension folder and the Claude Code hook installer inside it. Check: `codesign --verify --deep --strict apps/macos/.build/app/Porter.app` is silent, and `apps/macos/.build/app/Porter.app/Contents/MacOS/Porter --self-test` passes.
2. Open the bundle. In the setup window, **VS Code companion → Install in …** installs it in each found editor (VS Code, Cursor, Windsurf). Reload an editor window, then the row should turn ready within a few seconds. Tell me whether the companion works inside Cursor or Windsurf (untested).
3. **Claude Code status → Turn on…** asks first, then runs the bundled hook installer. Check `~/.claude/settings.json` gained Porter's hooks, that a dated backup exists next to it, and that your other settings are unchanged. Start a new Claude Code session to see Working and Needs you.
4. **Chrome extension → Set up…** registers the helper in the bundle with Chrome (this replaces the development registration that points into the repository) and writes the file that makes Chrome offer the bundled, signed extension. Quit Chrome completely and reopen it: it should offer to add or enable "Porter" in each profile; approve it in the ones you want. The row should then turn ready. Quit Porter and reopen: the extension must reconnect. The extension's id changes from the development one, because the bundled copy is signed with a key generated on this Mac (`~/.porter-signing/chrome-extension.pem`: back it up, never commit it). Without that file the id would differ on every machine. Automated check without touching your profiles: `apps/macos/scripts/check-extension-install.sh`.
5. **Open at login** turns on and off from the same window; macOS may ask you to approve it under System Settings → General → Login Items. `apps/macos/scripts/build-dmg.sh` makes `Porter.dmg` (drag Porter to Applications); open it and check both items are there.
6. Not covered yet: signing with a Developer ID, notarization (the script has the steps but they have not run), and updates. Everything above is signed ad hoc.

**K. Setup window** (the one place that says what works and what needs a permission). Windows that run an out-of-date VS Code companion are named here ("N of them need a reload"): a window only loads the companion when it opens or reloads, so after an update run Developer: Reload Window (⇧⌘P) in each, or quit and reopen VS Code.
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
6a. When a status does not show, `services/native-host/.build/release/porterctl sessions` (or the copy inside `Porter.app/Contents/Helpers`) lists each agent session the registry has heard from, its folder, state, age and the tab it is tied to. No line for a chat means no hook event has arrived from it (a session that began before the hooks were turned on never sends any: start a new one); a line with `not tied to a tab` means Porter could not tell which tab (it ties a session at its first submitted prompt, to the tab that came to the front last in that window).
6b. Several tabs in one window (needs the VS Code windows reloaded so the companion reports when each tab came to the front, and a Claude Code session started after the hooks were turned on): open two Claude Code tabs in one window, send a prompt in the first and, while it works, switch to the second. The first tab should show Working and the second Unknown (or its own status once you prompt it). Prompt in the second: each tab keeps its own status. A session whose first prompt was sent before Porter was running stays Unknown until its next prompt.
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

