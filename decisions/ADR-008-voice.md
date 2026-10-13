---
id: "ADR-008"
type: "decision"
title: "Opt-in local speech and evidence-based completion notices"
status: "accepted"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/macos", "area/ux", "area/security", "phase/r1"]
summary: "Apply PLAN-004 defaults: structural completion evidence, metadata-only local speech, push to talk first, and distinct interruptions."
related: ["PLAN-004", "DOC-CONSTITUTION", "DOC-QUESTIONS"]
---

# ADR-008 — Voice defaults and boundaries

Prem directed execution on 2026-10-10. The assistant stated and applied the three
defaults accompanying that direction: push to talk first; "Task completed: {title}"
with English phrases and a project template option; interrupted turns spoken
differently and excluded from completion notifications (Q-025 to Q-027).

Prem revised Q-026 on 2026-10-10: completion speech and notice titles name the
assistant, saying "Claude has completed a task" or "Chat GPT has completed a
task". The title and project remain in the notification body for navigation;
the spoken completion line does not include them. A mixed-source batch uses a
neutral task count.

Completion requires fresh work observed by Porter and a newer structural end:
Claude Code Stop or Codex completed/aborted markers. Lapse, startup history,
lost connectors, and session termination never stand in for completion.

New completion notifications and speech are off by default. Existing Needs-you
notifications keep their prior default. Speech uses system synthesis and only
the panel's title/project metadata. The default voice follows the Mac; explicit
voice choices are English. No microphone permission is needed for speech output.

Commands remain deterministic navigation through the click activation path.
Prem then directed the push-to-talk command path to be built. It provisionally
uses the available en-US `SFSpeechRecognizer` with on-device recognition required;
runtime capability and both permissions are checked before opening the mic.
TASK-093 still owes accuracy and cost measurements before this choice can be
accepted for real names. There is no cloud fallback, always-on listener, or new
package dependency. Wake phrase requires separate continuous-listening evidence.
Reply dictation is TASK-050/M6.

Screen-lock observation currently uses names verified in the installed loginwindow
binary, not a documented vendor contract. Unknown startup state suppresses speech
until unlock or Setup voice interaction. Batch U must establish live behavior.
