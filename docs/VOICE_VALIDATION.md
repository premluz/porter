---
id: "DOC-VOICE-VALIDATION"
type: "spec"
title: "Voice validation and batch U"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/quality", "area/macos", "area/security", "phase/r1"]
summary: "Scripted voice checks, recognition evidence gate, and human sound review."
related: ["PLAN-004", "DOC-VALIDATION"]
---

# Voice validation and batch U

Run `bash tools/verify_voice.sh` from the project root. It runs contracts, core,
native-host, Mac and recognition-spike tests, a release build, the off-screen app
self-test and memory checks. Native-host tests bind temporary Unix sockets; a
restricted execution environment must allow that test capability. Logs retain
failing output. No permission prompts or audio capture occur in this script.

Run `python3 tools/check_codex_turn_headers.py` for the structural-header check.
It reports counts only, groups real VS Code and other session files, accepts the
ordinal and pre-ordinal headers, and fails when a second dataset is unavailable
or a header differs. It prints no title, transcript, workspace, or session ID.

Mac tests generate component-scoped `settings.png` and `speaking.png` beneath
`apps/macos/.build/voice-preview/`; the log prints the exact directory. These
are first review artifacts, not approved visual baselines. Existing docked-face
pixel checks remain automated. Human approval of spacing and appearance is owed.

## Batch U: sound and notices

Run the bundled app's Setup and its Preview voice control. Human evidence is
required for voice quality, timing, completion-notice click behavior and the
speaking face. Record observations in PLAN-004; these are not automated passes.
The phrase, queue, interruption handling, coalescing, exact activation route,
off defaults, persistence and quiet policy are exercised by the script's tests.
No completion notice is emitted for interrupted events. Speech uses metadata
only. Its system-default voice may follow the Mac's language; selectable voices
are English and the phrases are English.

Screen lock uses local loginwindow notifications, whose names were confirmed
in the installed loginwindow executable. The initial optional lock key is not
a documented Apple contract. Missing state suppresses speech until an unlock
notification or a user interaction with the voice controls in Setup. Actual
lock/unlock behavior remains human evidence, including lock during speech.

No verification available for audible output, real notification delivery/clicks,
lock-transition timing, or human visual approval in this session. Checked instead:
fake synthesis, model routing, scoped render artifacts, existing pixel tests,
settings persistence and native builds.

## TASK-093 recognition evidence

Use the [recognition harness](../spikes/voice-recognition/README.md) and its
`Scripts/build-app.sh` and `Scripts/measure.sh`. The same 30 distinct real names
and recordings must be measured with both recognizers; permissions are requested
only from the harness's separate buttons. Record accuracy, warm and cold latency,
permission behavior, client and recognizer-service CPU, and battery energy.
No audio or name corpus belongs in project memory. Read-only capability checks
and file CPU alone do not satisfy this gate.

TASK-095 now has a provisional push-to-talk path: Voice commands starts off,
Microphone and Speech Recognition are requested from separate Setup buttons,
and held ⌃⌥V uses en-US on-device recognition for navigation. A start cue finishes
before audio capture, a different stop cue follows capture, and partial transcripts
survive an empty final result after release. Check both sounds and whether a real
spoken command opens its target in batch U. The reply window
remains unimplemented. The 30-name comparison, live recognition, shortcut
release timing and both permission prompts are unverified human evidence.
TASK-096 remains gated on a measured continuous-listening go result. Voice
dictation into other apps remains TASK-050/M6. Desktop-chat completion still
depends on batch T in [existing manual validation](VALIDATION_MANUAL.md).
