---
id: "PLAN-004"
type: "plan"
title: "Hands-free: completion notices, spoken announcements and voice navigation"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/macos", "area/ux", "area/security", "phase/r1"]
summary: "Announce when an agent's turn ends (notification and, optionally, a spoken line with the task's name) and let the person say \"Porter, show the task\" or \"show <name>\" to bring it forward; all on the Mac, no cloud, no tokens. Dictating replies is the later composer milestone."
related: ["PLAN-002", "PLAN-003", "DOC-PLAN"]
---

# PLAN-004 — Hands-free: completion notices, spoken announcements and voice navigation

## What Prem asked for (2026-10-10)

Work hands-free across projects. When a chat finishes, Porter can tell you: a notification, and, as a setting, a spoken line such as "Task completed: <task name>" or "<project> has completed". You answer by voice: "Porter, show the task" brings the one just announced (the most recent) forward; "Porter, show <task name>" brings that one forward. Everything runs on the Mac, with no tokens or cloud service. Later: compose a reply into the chat by voice.

## Boundaries (from the constitution and ADR-001)

- **Navigation only in this plan.** Announcing and bringing a chat forward are navigation; nothing here types into, sends to, or approves anything in another app. Dictating a reply is the M6 composer (TASK-050), with its own per-source spike and decision; this plan only leaves a seam for it.
- **No conversation content.** Announcements speak the chat's title and project, which the panel already shows, never message text. A turn's end is detected from the same structural signals as status (hook events, Codex turn records), never by reading replies.
- **Unknown stays Unknown.** "Completed" is announced only for a turn Porter saw working and then saw end by a real end signal. A working status that lapsed (stale, connector gone) is never announced as completed (RISK-002).
- **On the device.** Speech out with the system synthesizer, speech in with the system's on-device recognizer. No audio or transcript is kept or sent. No new package dependency unless a spike shows the system recognizer is not good enough, and then only after Prem approves it.
- **Opt-in.** Every part is off until switched on, and each permission (Notifications, Microphone, Speech Recognition) is asked for only from its own button in Setup, as Notifications is today.

## How it fits (architecture)

```
 sources ──► registry (core) ──► AppModel.rebuild ──► CompletionDetector ──► Announcer(s)
 hooks: Stop                       statuses + turnEndedAt      (pure)          ├─ NoticeAnnouncer   (UserNotifications, exists for Needs you)
 Codex: task_complete / turn_aborted                                           └─ SpeechAnnouncer   (AVSpeechSynthesizer)
                                                                                         │ "Task completed: Fix login, in Atlas"
                                                                                         ▼
 push-to-talk hotkey / reply window ──► VoiceListener (on-device recognizer) ──► CommandParser (pure) ──► VoiceRouter ──► AppModel (activate, open pane with query)
                                                                                                              └─ SpeechAnnouncer (confirmations: "Opening Fix login")
```

1. **A turn-ended signal in the core (TASK-090).** Today the registry knows "working" and, for Claude Code, "idle"; it does not keep *when a turn ended*. Add it as evidence, not a guess:
   - Claude Code: the `Stop` hook event (already received; today it only sets Idle) records `turnEndedAt` on the session, and through the existing binding on the route. `SessionEnd` is not a completion.
   - Codex: the connector already finds the last `task_complete` / `turn_aborted` marker (FACT-034); it reports that record's time on the app entry (`AppEntryReport.lastTurnEndedAt`, optional, plus the payload schema and fixtures), and whether it was an abort. The timestamp is the first field of the marker's own line, read as bytes like the marker.
   - Desktop apps' own chats: nothing until batch T finds their working signal; a Stop control disappearing would then be the end signal.
   - Exposed per route as `DestinationStatus.turnEndedAt` (and on `ItemStatus`), with which kind of end (completed or interrupted).
2. **CompletionDetector (TASK-091), pure.** Input: the previous and current items. Output: `Completion` events (item id, title, project, kind, time). Rule: an item that was fresh Working at an earlier rebuild and now has a `turnEndedAt` newer than the last one announced for it. At launch, and for anything Porter did not see working, nothing is announced. Several completions within a short window are coalesced into one event ("3 tasks completed"). Lives beside `announceWaiting` in `AppModel` (which it generalises: Needs you and Completed are both "events worth telling").
3. **Announcers (TASK-091, TASK-092).** One protocol, `Announcing`, with two implementations chosen by settings:
   - `NoticeAnnouncer`: the existing notifier, extended with a "completed" notice ("Atlas · Fix login completed"); clicking it opens that chat (navigation, as Needs you does).
   - `SpeechAnnouncer`: `AVSpeechSynthesizer` with a user-chosen system voice and rate. Phrases come from a small template set ("Task completed: {title}", "{project} has completed {title}", "{title} was interrupted", "{n} tasks completed"); titles are shortened and cleaned of symbols before speaking. It stays quiet while the person is speaking to Porter, never talks over itself (queue, newest wins for the same item), and can be told to stay quiet while the pane is open or the screen is locked.
4. **Voice input (TASK-093 spike, TASK-095).** `VoiceListener` wraps the system's on-device recognizer. macOS 26 has the newer `SpeechAnalyzer`/`SpeechTranscriber` and the older `SFSpeechRecognizer` (with `requiresOnDeviceRecognition`); which one to use is the spike's job, measured on project and chat names, not assumed. Listening only happens in one of these modes, in order of build:
   - **Push to talk** (first): hold a global shortcut (a second one beside ⌃⌥Space), speak, release. Nothing is heard otherwise.
   - **Reply window**: for a few seconds after an announcement, Porter listens for a command; the docked face shows it is listening. No wake word needed, because Porter just spoke.
   - **Wake phrase "Porter"** (later, only if the spike shows continuous on-device listening is cheap and accurate enough): opt-in, with a clear always-listening indicator.
5. **CommandParser and VoiceRouter (TASK-094, TASK-095), deterministic, no language model.** A closed grammar, tolerant of filler ("uh", "please") and of "Porter" at the start:
   - "show the task", "show it", "open it", "go there" → the item last announced, else the most recently completed.
   - "show <name>" / "open <name>" → the panel's existing search over title and project; one match is opened; several open the pane filtered to the query and Porter says "Two matches"; none says "Nothing called <name>".
   - "what's waiting" / "show needs you" → the pane, Needs you section; "what's working" → spoken count and names.
   - "cancel", "stop", "never mind" → stop speaking, close the listening window.
   - Opening uses the same `AppModel` activation paths as a click, so route choice, re-verification and failure feedback behave the same; failures are spoken briefly.
6. **Seam for the composer (not built).** `CommandParser` returns `.dictate(target)` for "reply to <name> …" and the router answers "Replying by voice is not available yet". M6 will plug a draft into the composer there.

## Settings (one "Notifications and voice" section in Setup)

| Setting | Default | Notes |
| --- | --- | --- |
| Notify when a chat needs you | On (exists) | |
| Notify when a task completes | Off | Notice per completion, coalesced |
| Speak announcements (voice mode) | Off | Needs no permission |
| Voice, speed | System voice, normal | Preview button |
| What to say | "Task completed: {title}" | Choice of the templates above |
| Quiet while the pane is open / screen is locked | On / On | |
| Voice commands | Off | Asks Microphone and Speech Recognition from this row |
| Command shortcut (push to talk) | ⌃⌥V, hold | Changeable |
| Listen after an announcement | Off | Reply window length 6 s |

Stored like `PanelSettings` (user defaults, `porter.voice.*`). The docked face gains a "listening" look (eyes up, a soft ring) and a "speaking" look; both are states of `MascotView`, not new windows.

## Tasks (for agents to claim in TASKS.md)

| Task | Depends on | Can start now | Deliverable and evidence |
| --- | --- | --- | --- |
| TASK-090 Turn-ended signal | none | yes | Core: `turnEndedAt` from `Stop` and Codex markers, contract field + fixtures, status exposure; tests for completed, interrupted, lapsed-is-not-ended, launch-is-not-ended |
| TASK-091 Completion events and notices | TASK-090 | after 090 | `CompletionDetector`, `Announcing`, completed notices, settings rows; tests incl. coalescing and no announcement for unseen work |
| TASK-092 Spoken announcements | TASK-091 | after 091 | `SpeechAnnouncer`, templates, voice and rate, quiet rules, preview; tests on a fake synthesizer; batch U for the sound |
| TASK-093 Spike: on-device recognition | none | yes | FACT: `SpeechAnalyzer` vs `SFSpeechRecognizer` on macOS 26: latency, accuracy on 30 real project and chat names (names only), CPU and battery while listening, permission prompts in the bundled app; go/no-go for the wake phrase |
| TASK-094 Command grammar | none | yes | Pure `CommandParser` + matcher over panel items; table-driven tests with filler words and near-miss names |
| TASK-095 Voice commands | TASK-093, TASK-094 | after both | `VoiceListener`, push to talk, reply window, `VoiceRouter`, spoken confirmations, listening face; batch U |
| TASK-096 Wake phrase | TASK-095, spike go | later | Opt-in always-listening with indicator |
| (TASK-050, M6) Reply by voice | composer milestone | no | Out of this plan |

Three agents can start at once on TASK-090, TASK-093 and TASK-094; they touch different packages (core, a spike folder, the panel model).

## Risks and checks

- A wrong "completed" (lapsed status read as done) breaks trust: only end signals count, with tests for each lapse path.
- Speaking chat titles aloud in a shared room: off by default, said plainly in the settings row.
- Recognition of invented project names ("Amble", "Memento"): the spike measures it; the matcher allows close matches and asks when unsure.
- Ad-hoc signing re-asks Microphone and Speech Recognition after each rebuild, as Accessibility does; Developer ID signing (TASK-027) fixes it.
- Microphone use is visible in the menu bar's privacy indicator; Porter never listens outside the modes above.

## Not verifiable by an agent here

Sound, the feel of the timing, and recognition with a real voice need a person; they go in a manual batch (U) written with TASK-092 and TASK-095.

## Execution checkpoint — 2026-10-10

- Q-025 to Q-027's stated defaults applied to Prem's "execute" (ADR-008).
- TASK-090, TASK-091 and TASK-094 implemented and verified by scripted gates.
- TASK-092 implemented with fake-synthesizer checks and a speaking face; sound,
  real notice clicks, lock transitions and visual approval remain [batch U](../docs/VOICE_VALIDATION.md).
- TASK-093 has a [comparison harness](../spikes/voice-recognition/README.md),
  builds/tests and real capability observations (FACT-036). The 30-name audio
  corpus, human permission observation and live cost evidence are still absent.
- TASK-095 remains blocked on that recognizer decision; TASK-096 is deferred
  until continuous-listening measurements establish a go. Neither listens yet.
- Run `bash tools/verify_voice.sh`; use `python3 tools/check_codex_turn_headers.py`
  for real structural-header compatibility. No new dependencies were added.

## Revised voice checkpoint — 2026-10-10

- Prem revised completion wording to "Claude has completed a task" or "Chat GPT
  has completed a task"; the prior title/project speech choice was removed.
- Prem directed voice commands to execute. A provisional en-US on-device
  `SFSpeechRecognizer` listener is wired to held ⌃⌥V, with separate Setup
  permission buttons and deterministic navigation. This advances TASK-095
  while TASK-093's real-name comparison remains open.
- Reply-window listening and the wake phrase remain unbuilt. Live speech,
  permission and timing evidence still belong to batch U and TASK-093.
