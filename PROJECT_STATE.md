---
id: "DOC-STATE"
type: "state"
title: "Current project state"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "area/product", "phase/foundation"]
summary: "Short current checkpoint and exact next action."
related: ["PLAN-001", "DOC-TASKS", "DOC-QUESTIONS"]
---

# Current project state

As of 2026-10-08. Refresh after a meaningful milestone; this file is a snapshot, not the historical log.

## Exists

- Technical, UX, data, security, delivery, and memory specifications.
- Shared AGENTS.md entry point and Claude Code import shim.
- Task ledger, decision records, first feasibility plan, and initial progress entry.
- Local documentation index/search/validation utility and derived catalog.
- Documentation checks pass; eight local tooling behavior tests pass.
- Product name is Porter (FACT-011); sibling products Manager, Atlas and Memento are linked by opaque references only (ADR-004, proposed).
- Reference Mac inventoried (FACT-009).
- `packages/contracts`: 9 JSON Schemas with valid/invalid fixtures (`npm run validate`).
- `packages/ConversationCore`: Swift identity, status, envelope, sequencing, registry and bridge coordinator; 57 tests pass; builds for the iOS Simulator.
- `services/native-host`: framing, same-user sockets, registry service, relay, `porter-registryd`, `porterctl`; 13 tests pass, six against the real relay binary.
- `packages/ConversationCore` also holds `PorterStore` (pins, hidden items, SQLite) and `PorterPanelModel` (panel contents, keyboard selection, recovery messages, context packet review); `apps/macos` is the Mac panel (SwiftUI Liquid Glass in a non-activating window, ⌃⌥Space, menu-bar item, embedded registry, `--fixtures` sample mode, `--self-test`); `apps/ios` is a sample-data iPhone list. All pass their automated checks; none has been looked at by a person (FACT-017).
- `extensions/chrome`: MV3 connector with a provider adapter registry (Claude verified, ChatGPT untested); 33 tests pass; extension ID `eilmjgagnblkgijjdedkmdnjogggdeij`. Observed working in two real Chrome profiles (list, activate, rename, navigate, quit and relaunch).

## Does not exist yet

No sync backend, remote composer, status adapter, signed installer or deployed service has been created. The Mac app is a development executable, not a signed bundle. The repository is not under git. Platform feasibility (bridge, panel, deep links) remains unverified.

## Product baseline

Mac edge pane for open/recent/pinned conversations; exact-destination navigation; status only when observed. Full roadmap includes an iPhone companion. Preview, composer, and summaries are later milestones. Phone platform is assumed to be iPhone, not yet explicitly confirmed by the user.

## Current implementation defaults

SwiftUI/AppKit, Chrome Manifest V3, TypeScript adapters, and a small native messaging helper are proposed. macOS 26+/iOS 26+ and Apple silicon first are provisional native-glass targets, to be verified against the user's devices and SDK. Older OS fallback and Intel are open scope questions. CloudKit private-database synchronization is a proposal, not an established capability.

## Next action

Direction set 2026-10-09 (ADR-006, PLAN-002): v1 is one app package that reads Chrome, VS Code, the ChatGPT app, the Claude app and other sources natively, with the browser extension and VS Code companion as optional enhancers. Next build step is TASK-080 (adapter boundary), then the spikes TASK-081 to TASK-083. Manual test batches below are still owed.

Run the manual test batch in [docs/VALIDATION_RELEASE.md](docs/VALIDATION_RELEASE.md) (appearance and feel of the Mac panel, the live app with real Chrome, the Claude desktop link, packet review, the phone app, the ChatGPT adapter). Everything it covers is built and passes its automated checks but has never been looked at by a person. After that: provider status signals (TASK-013), a runnable signed app bundle and installer (TASK-027), and CloudKit sync (TASK-030). Record the ADR-002 and ADR-005 decisions once the panel is judged and the signed helper exists. Distribution assumption to record before TASK-027: Developer ID with notarization, because the Chrome native-host manifest must be installed outside an App Store sandbox. In parallel only if explicitly requested, other contributors can work on isolated tasks under the coordination rules.

## Highest uncertainty

1. ChatGPT/Claude desktop chat discovery and status access on the installed builds.
2. Detecting web status consistently without retaining conversation text.
3. Cross-profile identity, service account switching, and reconnection after browser restart.
4. Phone sync latency and correct mobile opening under different accounts.
5. Native glass capsule-to-pane behavior across Spaces, displays, and accessibility settings.

## Evidence and authority

TASKS.md owns task statuses. PROGRESS.md owns historical events. memory/FACTS.md owns durable facts. ADRs own technical decisions. Current docs are a proposed engineering scope based on the user's expressed product direction; they are not a vendor-certified design.

## Suggested handoff prompt

“Read AGENTS.md and PROJECT_STATE.md. Continue with the next chosen slice (TASK-014, an iOS app target, or TASK-013) under plans/PLAN-001-feasibility.md. Prove the browser bridge and destination identity on macOS before building broad provider integrations. Update the task ledger and evidence; do not claim unavailable native tests passed.”
