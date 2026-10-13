---
id: "DOC-VALIDATION"
type: "spec"
title: "Validation and release plan"
status: "draft"
updated: "2026-10-10"
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

## Human validation

Existing [manual batches A–T](VALIDATION_MANUAL.md) retain their checks and evidence requirements.
Voice [batch U and the recognition gate](VOICE_VALIDATION.md) are separate.

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
