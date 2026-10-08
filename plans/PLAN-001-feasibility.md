---
id: "PLAN-001"
type: "plan"
title: "Prove the Mac conversation-switcher foundations"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/macos", "area/browser", "area/identity", "area/quality", "phase/r0"]
summary: "Executable first milestone with platform experiments and evidence gates."
related: ["DOC-ARCHITECTURE", "DOC-DATA", "DOC-VALIDATION", "ADR-002"]
---

# PLAN-001 — Prove the Mac foundations

## Purpose

Show that a user can select an observed conversation and return to the correct browser profile/window/tab through a native Mac UI. Establish the limits of desktop links and status observation. Prototype the requested liquid edge-pane transition. This plan covers TASK-010 through TASK-014 and produces evidence for the first implementation decisions.

## Current context

The repository contains documentation and a Python memory utility only. There is no Xcode project, extension, host executable, application database, MCP server, signing configuration, or remote service. The first implementation agent must scaffold these minimal experimental targets on a Mac. The current writing environment was Linux; no native result should be inferred from this plan.

Product baseline: navigation/status first; ordinary chats included; decisions remain in the original tool. A conversation is distinct from its destination. A provider account is distinct from a browser profile. Unknown status and account identity must be explicit.

Read docs/DATA_CONTRACTS.md for entity/envelope definitions and docs/SECURITY_PRIVACY.md for the allowed action boundary. ADR-002 is proposed until the bridge and visual experiments pass.

## Progress

- [x] Feasibility scope and acceptance defined in this document.
- [x] TASK-010: inventory actual Mac and supported source versions (FACT-009).
- [x] TASK-011: prove two-profile native messaging and activation (LOG-20261008-004 to -007).
- [x] TASK-012: implement schema/identity/status core tests (LOG-20261008-003).
- [ ] TASK-013: evaluate provider status and desktop link capabilities.
- [ ] TASK-014: prototype glass transition and accessible fallback.
- [ ] Write actual commands, test results, decisions, and updated estimates.

Task ownership/status remains in TASKS.md; this checklist records evidence milestones within this plan.

## Step 1 — Inventory and initialize

On the target Mac, from the intended project folder, run:

```sh
sw_vers
uname -m
xcodebuild -version
xcodebuild -showsdks
python3 tools/project_memory.py check
```

Record actual OS/architecture/Xcode/SDK values. Check Chrome and target desktop app versions in their About screens. Confirm which profiles can be used with non-sensitive fixture chats. If Xcode or required hardware is unavailable, record the blocker and continue only platform-independent contracts/documentation; do not pretend Linux compilation validates AppKit.

Initialize the app code in the same repository using the proposed layout from docs/ARCHITECTURE.md. Create a minimal Mac target and native host target; choose signing/bundle identifiers appropriate to the developer environment. Record generated project and scheme names. Add actual build/test commands to docs/VALIDATION_RELEASE.md once they exist.

## Step 2 — Prove connector isolation

Create `extensions/chrome/` with an MV3 manifest, a service worker, and an allowlisted content script for the first supported provider. Implement the contract handshake, a per-installation ID in local extension storage, and a small supported-tab inventory. Use optional host permission for the exact source origins; native messaging is required for the bridge.

Create `services/native-host/` with a minimal Swift helper implementing documented native messaging framing. Connect it to the single Mac registry service using the chosen authenticated local IPC mechanism. Verify this mechanism works when installed and launched by Chrome, including code signatures and per-user service lifecycle. Keep native commands limited to inventory/status and explicit activation.

Load the development extension in two Chrome profiles. Name them Personal and Work locally. Open distinct fixture chats with intentionally identical titles in two windows. The registry must retain two destinations with different connector identities. Activating each must focus the intended existing tab/window. Test a moved tab, a closed tab, browser restart, an unapproved extension ID, and a duplicated installation ID.

Pass evidence: a sanitized recording plus structured event/error IDs and TEST-001/002/011 results. Fail evidence is equally useful: document the exact obstacle and select a narrower fallback rather than hiding profile ambiguity.

## Step 3 — Lock contracts and reducers

Create a shared Swift package under `packages/ConversationCore/` and JSON schemas under `packages/contracts/`. Implement identity keys, ephemeral locator epochs, status/freshness reduction, event ordering, invalidation, and typed activation results.

Use tests with two same-title conversations, unknown account scope, account-epoch change, old sequence replay, missing snapshot event, stale working observation, conflicting observations, and rejected unexpected URL schemes. A passing happy path alone is insufficient for this component.

When created, run `swift test --package-path packages/ConversationCore` and the actual recorded schema validation command. Record results. These are future targets, not runnable commands in the starter pack.

## Step 4 — Provider capability experiment

For ChatGPT web and Claude web on the actual installed page versions, record:

- Supported canonical conversation route and title extraction.
- Whether provider account/workspace identity can be reliably observed without credentials.
- Working, idle, explicit user-question, and new-response signals.
- Behavior when the tab is backgrounded, frozen, discarded, signed out, or navigated.
- Minimal fixture representation and adapter version.

Store no real private message bodies. Use test conversations or redacted structural fixtures. If a signal is ambiguous, capability is limited/unknown. Do not interpret a missing spinner as successful task completion.

Test a copied desktop chat deep link for each intended desktop source where documented/available. Try correct account, changed account, app closed, and already-open app. Record activation separately from discovery and status. A provider API or CLI SDK does not prove control of existing consumer desktop chats.

## Step 5 — Native glass study

Create a fixture-driven capsule and pane within one AppKit-hosted SwiftUI surface. Test native glass shape identity transitions, host-window resizing, corner continuity, readable content reveal, and reversal mid-animation. Prove transparent areas pass clicks through rather than capturing desktop input.

Exercise both edges, two displays if available, screen scaling, full-screen Spaces, menu bar/Dock collisions, keyboard-only operation, VoiceOver, Reduce Motion, and Reduce Transparency. Record which conditions were unavailable; they remain untested. Select native material plus smooth resize if the exact morph is not reliable.

## Completion gate

- Two-profile activation is correct and rejected targets fail safely.
- Contract tests capture identity and staleness failures.
- Intended provider capabilities are recorded as verified/limited/unsupported/not-tested, with versions.
- Native-link results do not overclaim discovery/status.
- Glass approach and fallback chosen with visual evidence.
- Actual build/test commands, setup steps, and results exist in the repository.
- ADR-002 accepted or superseded; TASKS.md, PROJECT_STATE.md, HANDOFF.md and PROGRESS.md reflect actual outcomes.

## Recovery and repeatability

Use fixture chats and development extension IDs. Keep production/browser credentials untouched. Retest from a clean profile/user account before release. A reconnect requires a new epoch and snapshot; do not replay old navigation commands. If the helper installation fails, preserve logs without private content and document uninstall steps for only the files created by the experiment. Never instruct broad deletion of browser or agent state.

## Discoveries

- 2026-10-08: environment in FACT-009. `ChatGPT.app` on the reference Mac is Codex; Claude.app registers `claude://`, but no chat deep link has been verified. A Chrome extension cannot read its profile name, so profiles are identified by per-install ID plus a user alias.
- 2026-10-08 (real Chrome, one profile): detection, listing, duplicate-tab ambiguity, activation from another tab, and a `targetGone` refusal worked end to end (LOG-20261008-005). Two profiles were observed activating correctly in both directions and Chrome came forward from another app. TEST-001 (identical titles across two profiles) passed in both directions. `targetChanged` refused a stale revision. Chrome quit and relaunch reconnected both profiles with new route IDs (LOG-20261008-007).
- 2026-10-08: renaming a chat in one real profile made its tab drop out of a tab list and return, which previously produced a new route ID each time; fixed with bounded route memory (LOG-20261008-006). The reason for the drop-out is unmeasured.
- 2026-10-08: the panel (step 5) was built as one SwiftUI view in a non-activating AppKit window that is exactly the visible shape, with corner radius and content following the live window width during a frame animation; no morph effect is used between two glass views. This is the "native material plus smooth resize" fallback chosen up front, not a verified result: whether it looks acceptable is for a person to judge.
- 2026-10-08: Claude documents `claude://claude.ai/chat/<id>`; the ChatGPT app on this Mac is Codex and documents only local thread links (FACT-016). The desktop-link action is built for Claude only.
- 2026-10-08: step 2 differs from the plan in two ways, both deliberate. The extension has no content script because identity and title come from the tab URL and title, so there is nothing to scrape; the content script returns with status work (TASK-013). The registry link uses same-user Unix sockets instead of XPC (ADR-005).
- 2026-10-08: duplicate tabs of one chat are two routes in one profile; they are listed as ambiguous and the user chooses. A reconnect removes every old route and starts from a fresh snapshot, so tab IDs from before a browser restart are never reused.
- 2026-10-08: Ajv strict mode must allow conditional `required` (`strictRequired: false`); every other strict check stays on.

## Decisions

Proposed architecture is ADR-002. No platform feasibility decision has yet been accepted. Record changes by ADR ID and link, not a competing untracked decision list.

## Outcomes

Pending execution. This plan's completion does not mean the full R1 product or phone companion is ready.
