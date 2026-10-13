---
id: "DOC-LOG-20261010-VOICE-CUES"
type: "log"
title: "Voice cue and recognition checkpoint"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/macos", "phase/r1"]
summary: "Push-to-talk start/stop cues and partial recognition retention."
related: ["DOC-PROGRESS", "PLAN-004"]
---

# Voice cue and recognition checkpoint

## LOG-20261010-019 — Listening cues and short-command retention

- Date: 2026-10-10. Author: assistant. Task: TASK-095.
- Prem reported a no-speech error and intermittent inaction from the speech shortcut, and requested listening-on and listening-off sounds.
- Changed: Tink plays before microphone capture starts, Morse plays after it stops; a canceled start never opens the microphone. Recognition starts before the engine, requests partial results and retains the latest nonempty transcript when finalization returns an empty result or error after key release. The Speech callback explicitly crosses to the main actor.
- Verified: focused Mac listener test and full voice gate. Live microphone accuracy and audible cue behavior still require batch U.
