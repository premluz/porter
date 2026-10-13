---
id: "DOC-HANDOFF"
type: "handoff"
title: "Current handoff"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/memory", "phase/foundation", "phase/r0"]
summary: "Minimal restart packet for the next implementation agent."
related: ["DOC-STATE", "PLAN-001", "DOC-PROGRESS"]
---

# Current handoff

- Date: 2026-10-10.
- Owner of next implementation task: unassigned.
- Project: Porter (formerly the working name Conversation Switcher); owner Prem.
- Delivered: Markdown foundation and local project-memory tooling. Read [state](../PROJECT_STATE.md) for the current truth.
- Done: TASK-010, TASK-011 (observed in real Chrome), TASK-012, TASK-020. Built but awaiting a human: the Mac panel, live Mac app, packet review, phone sample app, ChatGPT adapter (LOG-20261008-008, manual batch in docs/VALIDATION_RELEASE.md). Next after that review: TASK-013 status signals, TASK-027 signed bundle, TASK-030 sync.
- Native environment needed: Mac with Xcode and actual target browser profiles/apps; iPhone needed later for R2.
- First proof: two browser profiles report distinct supported conversation tabs through a native messaging bridge, and selecting a destination activates the correct existing tab/window.
- Major boundary: R1 navigation/status only; no approvals, prompt sending, previews, or summaries.
- Identity rule: conversation, destination, account scope, and temporary tab locator are separate. Unknown account identity is never silently merged.
- Key uncertainty: desktop discovery/status is not guaranteed by a deep link. Web status is per-provider and can be unknown.
- Design: minimal native glass capsule on screen edge expands into a pane; prove interruption, accessibility and click-through behavior.
- Run the Mac app: `cd apps/macos && swift build -c release && .build/release/Porter --fixtures` (sample) or without the flag (live; stop `porter-registryd` first). Open `apps/ios/Porter.xcodeproj` for the phone app.
- Implementation status: `packages/contracts`, `packages/ConversationCore`, `services/native-host` and `extensions/chrome` exist and pass their tests; no Mac app or iPhone app yet. Memento MCP (project "Porter") holds subjects for change reports; name at least one subject ID in every report.
- Commands available: `python3 tools/project_memory.py check`, `search`, `read`, `index`; product checks in [validation](../docs/VALIDATION_RELEASE.md).
- Avoid: copying private chat bodies into project memory; inferring success from disconnected tabs; inventing supported APIs; treating earlier rough estimates as commitments.

Read the next plan and only the technical/UX documents needed for that task. Update this packet when the next action changes.

## PLAN-004 handoff

- Turn-end signals, completion notices/coalescing and deterministic grammar built;
  source-specific completion wording and local speech built, human batch U owed.
- Run `bash tools/verify_voice.sh`; core, native-host, Mac, spike, release, self-test
  and memory gates are scripted. Render paths are printed by VoiceRenderTests.
- Push-to-talk ⌃⌥V, explicit Microphone/Speech permission buttons, on-device
  en-US listener and navigation router are built provisionally. Distinct listening
  cues and partial-result retention are built (LOG-20261010-019). No live audio
  validation yet. TASK-093 still needs 30 real name recordings, permission
  observations and live CPU/energy evidence; see [voice validation](../docs/VOICE_VALIDATION.md).
  TASK-095's reply window and live acceptance remain. No wake go.
- Initial unknown lock state keeps speech quiet until unlock or Setup voice
  interaction. Actual lock timing is unverified. No audio was captured here.
- Q-025 to Q-027 defaults were applied to "execute"; see ADR-008. Historical log
  and foundation-fact splits preserve every existing record ID.
