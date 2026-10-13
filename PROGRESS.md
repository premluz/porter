---
id: "DOC-PROGRESS"
type: "log"
title: "Project progress log"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/memory", "phase/foundation"]
summary: "Append-only checkpoint history with evidence and next actions."
related: ["DOC-README", "DOC-TEMPLATES"]
---

# Progress log

Append checkpoints in date order. Each event uses a unique LOG ID, author, task IDs, evidence, limits, and next action. Use UTC timestamps when the actual time is known; a date alone is preferable to an invented time. Corrections are new entries referencing the old entry.

## Earlier checkpoints

- [Progress 20261008, part 1](memory/progress/2026-10-08-1.md)
- [Progress 20261008, part 2](memory/progress/2026-10-08-2.md)
- [Progress 20261009, part 1](memory/progress/2026-10-09-1.md)
- [Progress 20261009, part 2](memory/progress/2026-10-09-2.md)

## LOG-20261010-001 — Status ties survive a restart; a way to see why a status is missing

- Date: 2026-10-10.
- Author: assistant; Prem showed the Amble window (several Claude Code tabs, one visibly working) with no status in Porter, while this chat's window shows one.
- Finding: the Amble window runs companion 0.2.0 and its tabs have times, so the tie rule can work there. What I could establish is a weakness: ties lived in memory, so every restart of Porter (which I ask for after each rebuild) left running chats with hook events but no tie, and with several tabs in a window such a chat shows Unknown until its next prompt. What I could not establish is whether the Amble chat sends hook events at all (a session that started before the hooks were turned on never does); the registry gave no way to tell.
- Changed: ties are kept by the tab's connector-derived id (stable across runs) and saved to `agent-bindings.json` (mode 600, a week's life, 200 at most; unreadable files are logged and ignored); the registry restores them at start. A tie ends with its session, and a renamed tab (new id) is not claimed by the old tie. New `porterctl sessions` lists each session the registry knows (short id, folder, state, age, tab tied to). The diagnostic needs the app restarted once to speak the new command.
- Verified: core 122 tests (3 new: restart, rename and end, pruning and summary), native-host 75 (2 new: saving and loading, bad file), Mac app tests. Not verified: on the real windows.
- Next action: Prem restarts Porter and, when a chat's status is missing, runs `porterctl sessions`; the answer says whether the chat sends events at all or only lacks a tie.

## LOG-20261010-002 — "What this reads" under each source, and the privacy statement (from the review of One)

- Date: 2026-10-10.
- Author: assistant; Prem asked to build the things recommended from the review of One's FAQ.
- Changed: each source in the setup window carries one plain line on what it reads (tab titles and addresses, sidebar titles in the left strip, Codex's thread list, hook event names) and what it does not (pages, messages, prompts), written to match docs/SECURITY_PRIVACY.md; the window ends with "Nothing leaves this Mac. Porter has no account, no server and no analytics." Lines for terminal agents and notifications are written ahead of those rows.
- Verified: Mac app 80 tests (every row has a line; no line claims more than the privacy doc). Not verified: the look.

## LOG-20261010-003 — Needs you section and notices on the Mac (from the review of One)

- Date: 2026-10-10.
- Author: assistant.
- Changed: chats whose agent is waiting on the person (a fresh needs-you status, for now from Claude Code hook events) are listed in a "Needs you" section at the top of the pane, newest signal first, and not repeated among the pinned or open chats; they come first for keyboard selection and in the capsule. A notice "<Project> needs you / <chat title>" is posted on this Mac when a chat starts waiting (once per wait, none while the pane is open, taken down when it stops, posted again if it waits again); clicking it opens the pane. Setup gains a Notifications row (allow, or open the system settings when blocked); the permission is asked only from that button. Nothing is sent off the Mac.
- A bug the new test caught: the announce call first landed in the wrong method (a text match hit `toggleOlder` instead of `rebuild`); fixed.
- Verified: panel model 69 tests (3 new), Mac app 83 (3 new: notice lifecycle, quiet while open, setup row) and the self-test. Not verified: a real notice, which needs the bundled app, the permission and a waiting chat (batch P).
- Limits: status exists only where Porter has hook events, so only Claude Code in VS Code (and, once built, terminals) can be waiting; browser and desktop-app chats cannot.

## LOG-20261010-004 — Agents in terminals (from the review of One)

- Date: 2026-10-10.
- Author: assistant.
- Changed: until now Porter ignored any Claude Code session not started from VS Code's panel. The hook now places a session that did not (a terminal one) by walking up its parent processes to the terminal device and the hosting application, and sends both with its event (`TerminalProbe`). The registry lists such sessions as routes of their own (`TerminalSession`; `TerminalSessionsConnector`), keyed by session id with the project folder, the real time of its last event as the last-used time, its status (so Needs you and notices work for them) and, for Terminal and iTerm, the tab's title. Clicking brings a Terminal or iTerm tab forward by its device; VS Code's terminal brings its window forward; other known terminals are listed and report unsupported; an unknown host is not listed. The row says "Terminal" as its source. Setup gains an Agents in terminals row. The `tty` and `hostApp` fields are validated and optional.
- Verified: core 127 tests (5 new: listing, keeping the place, validation, status on the session's route, source label), native-host 86 (4 probe tests incl. the real process table; 7 connector tests on a fake runner), Mac app 84. Not verified: anything on a real terminal session (batch Q): the AppleScript for Terminal and iTerm has not been run, and no terminal session existed to try.
- Not done: bringing a tab forward in cmux, Ghostty, Warp, WezTerm, kitty or Alacritty; the activation feedback text still says "VS Code window" for these routes.

## LOG-20261010-005 — Dock states: tab, capsule you can drag, open pane (PLAN-003 steps 3 to 6)

- Date: 2026-10-10.
- Author: assistant.
- Changed: the panel now rests in one of two places and opens into the pane from either. **Docked**: a small tab flush with the left or right edge, flaring into it, showing up to three marks (a needs-you mark first, then working). Hovering it grows the capsule out of it ("peek") and leaving returns it after a short grace. **Floating**: the capsule anywhere on the screen. Dragging a floating capsule, or a docked tab or peek capsule pulled clear of its edge, moves it; near a left or right edge it is pulled towards that edge, and releasing within snap distance docks it, the capsule folding into the tab as one morphing shape. Near the top or bottom, where a standing capsule would not fit, the dots lie down in a row (with a little hysteresis so it does not flicker). Where it rests (mode, edge and height, or floating position) is remembered. The menu's Left and Right edge items dock it there. The drag decision is a pure function (`DockGeometry.dragStep`), so the controller only applies it.
- Files: `DockModel`, `PanelShape`, `PanelLayout`, `PanelPresentation`, `PanelController` (+`Rest`, +`Pointer`), `CapsuleView` (+ `TabView`), `PanelSettings`, `PanelMotion`, `EdgeGeometry`, `SelfTest`.
- Verified: Mac app 103 tests (dock geometry 9, shape, layout 4, drag step 4, motion) and the self-test, which checks that collapsing returns to the resting window when docked, floating and lying down; the animation probe still grows through 23 distinct sizes and settles at the pane width. Not verified: anything seen or felt (batch R): the drag, the pull, the flares, the liquid morph, the peek timing, the horizontal reflow and the tab's marks. This environment cannot capture the screen or drive the pointer.
- Not done: docking to the top or bottom edge (by design, see PLAN-003); a menu item to float it; dragging by the pane's own surface.

## LOG-20261010-006 — A face for the empty docked tab

- Date: 2026-10-10.
- Author: assistant.
- Changed: the docked tab shows the chats that are waiting on you or working, up to three, waiting first (unchanged). With none, it used to show a chevron; it now shows a small mascot, a round body with two eyes that look towards the middle of the screen (`MascotView`, tokens in `Tokens.Mascot`).
- Verified: Mac app 105 tests (2 new: the gaze direction from either edge, and that the face fits the tab) and the self-test. Not verified: how it looks (batch R, step 3).
- Asked about, not built: a metaball-style liquid join between the capsule and the tab (see PLAN-003, Progress).

## LOG-20261010-007 — The docked tab is solid black, with no outline

- Date: 2026-10-10.
- Author: assistant.
- Reported (screenshot): the docked tab was glass with a rounded pill outline inside it and straight lines running from it to the screen edge; it should be pure black like a camera cut-out.
- Cause: the tab's body kept rounded corners on the side against the screen edge, and the flares' straight edges did not meet its rounded end (the flare radius, 14, was larger than the room beside the end's curve, 22 deep less an 11 corner), so the one outline had a pill, a gap and straight seams.
- Changed: the surface is black while the tab rests (the glass and its edge line fade out as the tab becomes black, and back as the pane opens out of it), and the tab's marks and face are drawn light on it in both appearances. The outline: the body squares off where it meets the edge as the flare grows, the flare is clamped to the room beside the rounded end, and the flare token is 11, so the curve runs on from the rounded end with no seam. The tab is one closed contour (tested).
- Verified: Mac app 107 tests and the self-test; one offscreen render of the tab shape (no screen capture) shows a single black outline with smooth curves out to the edge and the face on it. Not verified: the real panel, with the black fade during docking and opening, and what a black tab looks like on a light page (batch R, step 3).

## LOG-20261010-008 — A liquid outline instead of stitched flares (ADR-007)

- Date: 2026-10-10.
- Author: assistant.
- Reported (screenshot on a light page): gaps between the tab and its flares, and a pill outline. The running Porter had started at 10:04, before the 10:07 build of LOG-20261010-007, so it showed the old outline; but that outline also opened gaps mid-fold, because the flares hung beside a body not yet at the edge.
- Read: the shader and animation code of the demo Prem linked (metaball-search.html): half-plane edge, rounded-box blob, gradient-aware smooth minimum copied from QuartzCore, springs for centre, size, fusion radius (64 attached, 10 detached) and darkness.
- Changed: the outline is now that field, traced into a path on the CPU each frame (`LiquidField`, `ContourTracer`, `EdgeFusion` on `ShapeSpec` in place of `flare`); the clip fills even-odd; the fillet reach is back to 14 pt. Apple's glass merging APIs were considered and not used (ADR-007).
- Verified: Mac app 112 tests (new: field reach, rounded box, traced circle within 0.05 pt, separate blobs, fillet reach and hollow on both edges, one outline, no gap at 21 steps of the fold) and the self-test; release animation probe 23 distinct sizes; one off-screen render of five fold frames (capsule, shrinking capsule, neck beginning, joined, tab) shows no gaps; worst trace 0.7 ms release, 14 ms debug (FACT-033). Not verified: on screen, with the material and the black fade (batch R).

## LOG-20261010-009 — The docked tab shows one mark for all the chats together

- Date: 2026-10-10.
- Author: assistant.
- Asked: the docked view should show one collective state: working if any chat is working, a question outranking everything.
- Assumption (not asked): with no fresh question and nothing working, the tab shows its face, not an idle or unread mark, so it claims nothing about the chats it cannot see working or waiting. A stale question or stale work is not claimed.
- Changed: `AppModel.tabStatus` (needs-you, else working, else none) replaces the list of up to three marks; the tab is a fixed size with one mark or the face; the mark count left `PanelLayout`, `DockGeometry` and the tokens (replacing LOG-20261010-005's "up to three marks").
- Verified: Mac app 114 tests (2 new: priority in any order, stale not claimed) and the self-test. Not verified: on screen (batch R, step 3).

## LOG-20261010-010 — Working status for Codex threads

- Date: 2026-10-10.
- Author: assistant.
- Reported: while Codex (or a chat) works in the ChatGPT desktop app, Porter shows no working status; Claude's desktop app may be the same.
- Cause: not a regression. Working status was only ever built for Claude Code (hook events, FACT-022). Every other source, the desktop apps and Codex included, was listed with no status, and the app's own "unread" marker is not turned into one.
- Changed: a connector can now report `working` on an app entry (`AppEntryReport`, the payload schema, one valid and one invalid fixture); the registry turns a report into a Working status for that route, announces the change, withdraws it when a report omits it or the entry leaves, and lets it lapse 45 seconds after the last report (`BridgeCoordinator+AppStatus`). The Codex connector reports a thread working when its session file shows an open turn and was written in the last 120 seconds (`CodexTurnState`, FACT-034), repeats the report every 15 seconds while it holds, and notices a turn starting or ending within its 5-second poll.
- Verified: core 132 tests (5 new), native-host (6 scanner tests incl. quoting, silence, missing file, a 12 MB record in under 250 ms, and 2 connector tests incl. the poll noticing a start and an end), contracts 77 fixtures, Mac app 114 and the self-test; live on this Mac, the connector reported 1 of 10 threads working, the one whose file was being written (counts and id prefix only). Not verified: the Working mark on screen for a real Codex turn (batch S), and the silence limit against real long tool calls.
- Not done: the Claude and ChatGPT desktop apps' own chats (no signal identified; reading their screen for a stop button needs a probe while a chat is generating and the Accessibility permission for the helper), Needs you for Codex (no approval record seen), and Claude Code side-panel chats (Q-022).

## LOG-20261010-011 — A probe to find the desktop apps' working signal

- Date: 2026-10-10.
- Author: assistant.
- Why: working status for the ChatGPT and Claude desktop apps' own chats needs a signal, and none is known (FACT-025). The likely one is a control that appears while a reply is written (a Stop button); its label has to be seen, not assumed.
- Changed: `Porter --probe-controls <bundle id> [seconds]` samples the app's window every 2 seconds and prints only the buttons outside the sidebar strip that were not present in every sample, labels cut to 40 characters (`ControlProbe`, `ControlProbeCommand`). Static text, the conversation and the sidebar are never read or printed. A diagnostic only; nothing else uses it.
- Verified: 2 tests on synthetic windows (strip and role filter, label cut, only changing controls reported); native-host and Mac builds. Not verified: any real run. The first attempt was refused because the rebuilt Porter is a new ad-hoc identity and has no Accessibility permission yet (batch T); this shell has none either.
- Next: with the permission, run it while each app is writing a reply, then build the adapters' working detection on the label seen and test it on it.

## LOG-20261010-012 — The docked tab's face carries the state, in colour

- Date: 2026-10-10.
- Author: assistant.
- Reported: the docked tab showed nothing readable for the state; it should be green if any chat is working, gray if nothing is happening, and anything needing attention first.
- Cause (as far as can be told without seeing the screen): a working chat was a thin green ring and a quiet one a pale face, both easy to miss on the black tab. The state was computed correctly (LOG-20261010-009).
- Changed: the face itself is coloured by the one state of all the chats: orange for a waiting question, else green for work in progress, else gray (`MascotTone`). The small status mark on the tab is gone.
- Verified: Mac app 115 tests (one new: priority and three distinct colours) and the self-test; one off-screen render of the three faces on the black tab shows all three clearly. Not verified: on the real screen with the real state (batch R, step 3), and that the "blank" tab seen was this cause and not an old build still running.

## LOG-20261010-013 — The docked tab's face was drawn off the tab

- Date: 2026-10-10.
- Author: assistant.
- Reported (screenshot): the docked tab is plain black with nothing in it, while the open capsule shows green.
- Cause: the panel stacks the tab's content with the pane's (360 pt wide) in one stack, and the tab's content filled the stack, so its face centred 180 pt off the 22 pt tab and was clipped away. This hid the face and the chevron before it from the first docked build, and the earlier "blank" fixes (LOG-20261010-009, -012) could not have cured it. My earlier off-screen renders drew the tab at a fixed 22 pt, outside the real stack, which is how it was missed.
- Changed: the tab's content is given the tab's own size (`PanelRootView`).
- Verified: a new test renders the real panel view as the docked tab, on both edges, and checks the pixels for a light face on the black tab; it fails without the one-line fix and passes with it. Mac app 116 tests and the self-test. Not verified: on the real screen.

## LOG-20261010-014 — Hands-free scoped (PLAN-004)

- Date: 2026-10-10.
- Author: assistant.
- Asked: notifications and, as a setting, spoken announcements when a chat's task completes ("Task completed: <name>"), and voice commands ("Porter, show the task", "show <name>") to bring it forward, all on the Mac with no tokens; replying by voice later.
- Done: PLAN-004 (architecture, boundaries, settings, task split for parallel agents), TASK-090 to TASK-096, Q-025 to Q-027. No code. Key points: a completion is only an end signal after observed work (hook `Stop`, Codex turn markers), never a lapsed status; speech out with the system synthesizer and in with the on-device recognizer, no new dependency; commands are a closed grammar mapped to existing navigation; dictating replies stays with the M6 composer.

## LOG-20261010-015 — PLAN-004 implemented through announcements; recognition gate remains

- Date: 2026-10-10. Author: assistant. Tasks: TASK-090 to TASK-096.
- Direction: "execute"; stated defaults Q-025 to Q-027 applied (ADR-008).
- Built: explicit turn-end signals, contract fields/fixtures, pure detector and
  fixed-window coalescer, opt-in notices with click activation, system speech,
  metadata templates, quiet policies, voice settings/preview and speaking face;
  deterministic command grammar/matcher reuses panel search.
- TASK-093: comparison harness, corpus/metrics tests and signed permission-probe
  bundle; capability observations in FACT-036. No audio capture or prompts run.
- Verification: `tools/verify_voice.sh` passes: core 238, native-host 101, Mac 126
  and spike 4 tests; 13 schemas/81 fixtures; release build, off-screen self-test,
  memory check. Socket/dSYM sandbox failures resolved in unrestricted verification.
  Real-header script passes ordinal and pre-ordinal datasets, counts only.
  The documentation utility's 8 behavior tests also pass. Latest settings text
  re-rendered both scoped artifacts and the release executable rebuilt successfully.
- Limits: batch U sound, notice clicks, lock transitions and visual approval;
  TASK-093's 30 real names/recordings, permissions and live cost evidence absent.
  TASK-095 blocked on the recognizer decision, TASK-096 deferred without wake go.
- History/foundation/validation documents split under the 200-line guardrail;
  every prior LOG and FACT ID preserved and relative links rebased.
- Additional regression: a fresh route cannot make another route's stale end
  eligible for an announcement; only fresh connected end evidence projects.
- Next: [voice validation](docs/VOICE_VALIDATION.md); no input is sent to other apps.

## LOG-20261010-016 — Setup window scrolls vertically

- Asked: make the settings window scrollable. Task area: TASK-084.
- Changed: SetupView uses the existing ScrollView pattern with a bounded height
  token; all source, notification and voice controls remain in its content stack.
- Verified: release build and 126 Mac tests pass; diff whitespace check passes.
- No verification available for live scrolling; inspected the scroll container,
  content padding and fixed viewport structure. No next-action change.

## LOG-20261010-017 — Assistant-specific completion and provisional voice commands

- Asked: say "Claude has completed a task" or "Chat GPT has completed a task",
  then execute the suggested voice navigation (TASK-092, TASK-095).
- Built: provider identity carried into completion events; source-specific
  speech/notice title; opt-in on-device en-US push-to-talk on held ⌃⌥V with
  separate permission buttons, parser routing and listening face.
- Verified: voice gate passes contracts (13 schemas/81 fixtures), core,
  native-host, Mac (126) and spike tests, release build, self-test and memory
  check. No audio, permissions or live shortcut tried here.
- Limits: TASK-093's 30-name/cost comparison and batch U remain open; reply
  window and wake phrase are not built.

## LOG-20261010-018 — ChatGPT app link and speech permission crash
- App link now `codex://threads/<id>` (installed app and Launch Services confirm); signed bundle installed with prior copy backed up. Live task click unverified.
- Three SIGTRAP reports traced Speech authorization to an off-main callback; explicit Sendable callback fixes it. Off-main regression, full voice gate (127 Mac tests), release build and app relaunch pass; live prompt unverified.

[LOG-20261010-019 — Listening cues and short-command retention](memory/progress/2026-10-10-voice-cues.md)

## LOG-20261013-001 — Live mascot planned on the Rios Brand character (PLAN-005)

- Date: 2026-10-13.
- Author: assistant.
- Asked: use the Rios Brand mascot (no limbs, capsule eyes) as the base for an animated, expressive face that follows the cursor and morphs like a liquid, splitting into agents; a modular system for later animation; additions integrated in Rios Brand.
- Read: Rios Brand's mascot code and docs. Verdict: reuse the character, its proportions, expression vocabulary and rules; not its runtime (a still-pose 3D editor that rebuilds meshes per pose, cannot split, and cannot run in the native panel).
- Done: PLAN-005 (spec JSON from the Rios definition, one animation behaviour implemented in TypeScript and Swift and held together by shared parity fixtures, liquid body by smooth union as in ADR-007, a web and a native renderer, task split TASK-097 to TASK-103). In Rios Brand: `git init` with a baseline commit of the existing project (`be6f0bd`, `.DS_Store` ignored, scanned for credentials first: none) and `docs/LIVE_MASCOT.md`. No product code.

## LOG-20261013-002 — Live mascot spec v1 (TASK-097, Rios Brand)

- Date: 2026-10-13.
- Author: assistant.
- Changed (Rios Brand, `src/tools/mascot-live/`): `constants.ts` (motion and liquid starting values, labelled as guesses for tuning), `spec.ts` (builds the versioned spec from the studio definition: three palettes, body radii, capsule eyes with the rig's own gaze travel, seven expressions as numbers), `spec-fields.ts` and `spec-parse.ts` (strict reader: exact fields, finite numbers, colours, ranges, one agent size per agent count, version 1 only), `spec/mascot-spec.v1.json` (exported copy), `pnpm spec:export`, `docs/LIVE_MASCOT.md`.
- Verified: Rios unit tests 72 (4 new: carries the definition, JSON round trip, nine kinds of bad input refused, exported file matches the definition), the drift test shown to fail on a hand-edited file and pass after restoring it, `pnpm check` (strict types and guardrails) and `pnpm build`. The studio's own code is untouched.
- Next: TASK-098 (animation core) and TASK-099 (liquid field), both on this spec.

## LOG-20261013-003 — Live mascot animation core (TASK-098, Rios Brand)

- Date: 2026-10-13.
- Author: assistant.
- Changed (Rios Brand, `src/tools/mascot-live/`): `random.ts` (Mulberry32, one stream per agent), `spring.ts` (semi-implicit Euler in fixed sub-steps, so ports agree), `gaze.ts`, `blink.ts`, `expression.ts`, `agents.ts`, `core.ts` (`initialState`, `step`, `frame`), `parity.ts` and `spec/mascot-parity.v1.json` (three scenarios, two seeds, uneven frame rates, split and merge), docs.
- Verified: Rios unit tests 79 (new: cursor following stays inside the gaze disk for random cursors and two seeds; return to the expression's look; blink intervals within the spec, seed-dependent and repeatable; no blink while an expression changes, shown to fail when that rule is removed; split to two and three and merge back; bad time steps refused; parity file matches the core), `pnpm check`, `pnpm build`.
- Not verified: how it looks or feels; there is no renderer yet (TASK-099 liquid field, TASK-100 live tool). The motion values are untuned starting points.

## LOG-20261013-004 — Live mascot liquid body (TASK-099, Rios Brand)

- Date: 2026-10-13.
- Author: assistant.
- Changed (Rios Brand, `src/tools/mascot-live/`): `liquid.ts` (agent frames to squashed, tilted ellipse blobs; scaled-radius ellipse distance; gradient-aware smooth union as in ADR-007; fusion radius at the smallest agent's size), `features.ts` (capsule eyes on each blob from gaze and lids; glow shading from the spec's light), spec v1 gains `light` (from the studio's `GLOW_LIGHT`; nothing consumed v1 yet), `field-parity.ts` (three shapes on a grid added to the parity file).
- Verified: Rios unit tests 83 (new: single-body distance and gradient; two agents joined while close, separate when apart, the gap only ever growing as they part, a far pair leaving each edge untouched; light from the upper left and a darker rim; every eye on its own body across every frame of the shared scenarios), `pnpm check`, `pnpm build`. One expectation of mine was wrong and was corrected, not the code: between far-apart agents the union lowers the field by a quarter of its reach exactly midway, which never reaches the outline.
- Not verified: the look; nothing draws it until TASK-100. Brows are not drawn yet.

## LOG-20261013-005 — Live mascot page in Rios Brand (TASK-100)

- Date: 2026-10-13.
- Author: assistant.
- Changed (Rios Brand `8f07511`): `#mascot/live` (`LiveEditor`, `LiveControls`, `useLiveMascot`, `renderer.ts`, `shader.ts`, `view.ts`, `tuning.ts`, `styles/live.css`), routing and navigation, a "Live mascot" link in Mascot Studio's heading. The shader runs the same field, shading and capsule eyes as the TypeScript code; the loop steps the core every display frame with the pointer read anywhere on the page. Live values changed after looking: eyes travel 30 units across the face (the studio's 6 was invisible in motion) and agents settle 2.5 radii apart (at 2.3 they still bulged toward each other).
- Verified: Rios unit tests 87 (4 new: pointer mapping, padded shader inputs and agent limits, tuning bounds, colours); 4 browser tests on the real page (opens from the studio, body pixels in the middle, a split fills empty space and a merge clears it, gaze follows the pointer left and right and stays put with reduced motion, palette changes the colour), five clean runs in a row after giving the first page load a longer, explained wait (Vite compiles on first visit); all 20 pixel baselines unchanged; `pnpm check`, `pnpm build`. One element screenshot each of a mid-split frame and a settled pair looked as intended (neck, glow, two bodies).
- Found and fixed: the extra heading link made Mascot Studio's mobile layout overflow (an existing test failed; shown by removing only the link); the heading buttons now wrap on phones. Seven failures in the first full browser run were checked: the holding and appearance ones passed on rerun at the same code while the machine's load average was 30–110, so they were timeouts under load, not regressions.
- Not verified: how it feels to a person; the tuning values; brows are still not drawn.

## Checkpoint format

Use the log template in [record templates](templates/RECORDS.md). Keep logs concise; link detailed test evidence instead of pasting terminal transcripts. Rotate older entries into dated files after approximately 150 entries or 64 KiB, preserving all LOG IDs and updating the index.
