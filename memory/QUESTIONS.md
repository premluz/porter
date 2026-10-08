---
id: "DOC-QUESTIONS"
type: "questions"
title: "Open questions and risks"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "area/identity", "area/security", "area/sync", "phase/r0"]
summary: "Unresolved choices and experiments that can settle them."
related: ["DOC-STATE", "PLAN-001", "ADR-003"]
---

# Open questions and risk register

Open questions are not automatic blockers to unrelated work. Proceed with documented reversible defaults and resolve a question before dependent implementation or claims.

| ID | Question | Proposed default | Resolution / owner |
| --- | --- | --- | --- |
| Q-001 | Final product name and bundle IDs? | Conversation Switcher working name; no released identifiers | 2026-10-08: name is Porter (FACT-011). Bundle IDs still open; Prem before signing |
| Q-002 | Which Mac OS/hardware must be supported? | macOS 26+, Apple silicon first | 2026-10-08: reference Mac is macOS 26.6.2 arm64 (FACT-009); package targets macOS 26 / iOS 26. Intel and older OS remain out of scope unless requested |
| Q-003 | Is phone specifically iPhone? | iPhone/iOS 26+ | Resolved 2026-10-08: iPhone (FACT-011) |
| Q-004 | First browser and service targets? | Chrome; ChatGPT web and Claude web | TASK-013. 2026-10-08: the installed "ChatGPT.app" is Codex (`com.openai.codex`); confirm the desktop targets with Prem (FACT-009) |
| Q-005 | Can each desktop tool expose a stable chat link? | Manually pinned verified link; unknown status | TASK-013 records app/version/link behavior. 2026-10-08: Claude documents `claude://claude.ai/chat/{id}`; Codex documents `codex://threads/<id>` for local threads only (FACT-016). Live behavior untested |
| Q-006 | How reliably can account/workspace changes be detected? | Keep unknown identities connector-scoped; never auto-merge | TASK-011/013 account-switch tests |
| Q-007 | Which web signals reliably distinguish waiting from idle? | Unknown unless explicit supported evidence | TASK-013 fixtures and live runs |
| Q-008 | Which native service packaging works with Chrome and XPC? | Signed helper plus per-user service | TASK-011 clean-user install/spike. 2026-10-08: prototype uses same-user Unix sockets (ADR-005); XPC and signature checks remain for TASK-027 |
| Q-009 | Does native glass support the desired large morph? | Native material with smooth resize fallback | TASK-014 visual and hit-test prototype |
| Q-010 | Is CloudKit sufficient for selected metadata sync? | Same Apple account; foreground convergence | TASK-030 validates enrollment, privacy and revocation; ADR-003 |
| Q-011 | Is stronger end-to-end encrypted device isolation needed? | Do not claim it; evaluate before content sync | TASK-030 plus R3 design review |
| Q-012 | Which sources can accept a message in an existing chat? | No universal send assumption; per-source draft/send | TASK-050; no reuse of provider API as presumed consumer-chat control |
| Q-013 | Which MCP clients will use project memory? | Filesystem access/local CLI first; optional stdio wrapper | TASK-070 client capability check. 2026-10-08: Memento MCP indexes this repo's Markdown; evaluate before building TASK-070 (LOG-20261008-003) |
| Q-014 | Where does Safari sit? Scope said out of R1; the kickoff makes it the second browser after its own checks | Chrome first; Safari macOS/iOS after its permission, packaging and release checks pass | Prem confirms whether Safari is in R1 or a later release before Phase 2 |
| Q-016 | What is the title format of real claude.ai chat tabs, and do tab titles change while a response streams? | " - Claude" suffix stripped; unknown otherwise | Partly observed 2026-10-08: titles shown by Porter matched the chat names, including after a rename; the raw browser title and the suffix format were not captured. Display only, never identity |
| Q-017 | Does `NSRunningApplication.activate()` from the registry bring Chrome forward from the background? | Reported as `app:` by `porterctl activate`, never assumed | 2026-10-08: observed working with another app in front when the registry ran from a terminal (FACT-014). Re-check when the registry runs inside the Mac app; if refused there, activate Chrome with the user's click as the activation source |
| Q-018 | Does the installed Claude app honour `claude://claude.ai/chat/<id>` for a chat from another account? | Documented to show recent chats on an invalid ID; Porter says it cannot confirm the account | Manual batch step B4; record exact behavior |
| Q-019 | Where do context packets come from in practice (file from Atlas/Manager/Memento, or a shared store)? | A JSON file the user opens in Porter; held in memory only | ADR-004 round trip with a real Atlas/Memento export |
| Q-020 | How should chats inside VS Code (Claude Code panel, OpenAI extension) appear in Porter? | Prem chose a VS Code companion extension (2026-10-08); a probe comes first because bringing one tab forward from outside is unproven | TASK-015; account-API route ruled out by S14 / FACT-019; OpenAI extension not yet examined |
| Q-021 | Can a stable ID for a Claude Code tab be had without reading conversation files? | Folder plus title plus order, with the limits in FACT-020 | Ask whether the extension exposes a session ID for its panels; otherwise accept the limit |
| Q-022 | Conversations in the Claude Code and Codex side panels are not editor tabs; can Porter see them? | No; only editor tabs are listed | Decide if side-panel chats matter enough to need a different mechanism (no public API found) |
| Q-015 | Where are suite context links stored, and what ID formats do Manager and Atlas use? | Store in the product where the user created the link; opaque string IDs | ADR-004 validation round trip |

## Risks

| ID | Risk | Impact | Mitigation / trigger |
| --- | --- | --- | --- |
| RISK-001 | Wrong conversation/account opens | Core trust failure | Epoch/revision checks, profile ownership, TEST-001–003; blocks R1 release |
| RISK-002 | Stale status appears live | Misleading attention model | Expiry and provenance; stale never implies completion |
| RISK-003 | Provider DOM changes | Status regression | Adapter isolation, fixtures, unknown fallback; versioned compatibility |
| RISK-004 | Broad platform scope absorbs schedule | Delayed useful product | One browser first; native links before discovery; milestone gates |
| RISK-005 | Pane intercepts desktop clicks/steals focus | Daily-use friction | Host-window hit testing, Spaces/display tests, keyboard fallback |
| RISK-006 | Phone sync is interpreted as real time | False mobile status promise | Last-observed age, foreground refresh contract |
| RISK-007 | Composer duplicates or misroutes a send | Unintended agent work | Explicit target, identity recheck, unknown-outcome state; no blind replay |
| RISK-008 | Memory becomes stale or contradictory | Agents implement old decisions | Canonical ownership, stable IDs, revision hashes, validator, superseding ADRs |
| RISK-009 | Concurrent agents overwrite shared state | Lost tasks or evidence | Worktrees/disjoint paths, integration owner, future revision-checked writes |
| RISK-010 | Metadata or preview leaks in diagnostics | Privacy loss | Redacted structured logs, opt-in previews, retention and deletion tests |

## Resolution record

When resolved, retain the question ID and add date, answer, evidence, and owning ADR/task. Remove it from the current-state uncertainty list only after evidence exists. Do not delete the original question and its rationale.
