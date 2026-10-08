---
id: "DOC-SOURCES"
type: "sources"
title: "Sources and attribution"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "area/mcp", "area/browser", "area/macos", "phase/foundation"]
summary: "Published sources and the limits of their applicability."
related: ["DOC-MEMORY", "DOC-FACTS"]
---

# Sources and attribution

Reviewed 2026-10-08. These are public documents, not access to private OpenAI or Anthropic team workflows. The proposed constitution, naming, tagging, task ledger, and folder structure are a project-specific synthesis. No single official “best-in-class internal setup” has been established.

## S01 — OpenAI project instructions

[Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

Supports using repository instructions and directory-scoped guidance. We use a short root AGENTS.md with task-relevant document routing. This does not imply a project file overrides the user's current request or host instructions.

## S02 — OpenAI living work plans

[Using PLANS.md for multi-hour problem solving](https://developers.openai.com/cookbook/articles/codex_exec_plans)

Supports resumable plans that capture progress, discoveries, decisions, validation and outcomes. Our roadmap and PLAN-001 adapt that idea; they are original documents, not copied vendor templates or mandatory Codex filenames beyond ordinary instruction discovery.

## S03 — Anthropic project memory

[How Claude remembers your project](https://code.claude.com/docs/en/memory)

Documents CLAUDE.md, imports, scoped rules and auto memory. We provide a thin CLAUDE.md import of shared instructions and portable repository records. Machine-local auto memory is distinct from this shared project catalog. Keeping always-loaded guidance short reduces duplicated context.

## S04 — Chrome tab APIs

[Tabs API](https://developer.chrome.com/docs/extensions/reference/api/tabs)

Supports tab/window locators, tab activation, tab metadata and lifecycle concepts including discarded/frozen tabs. Browser loading state is not AI task state. Exact app/account behavior still needs integration tests.

## S05 — Chrome native messaging

[Native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)

Documents extension-to-native-host messaging and host setup. Our Swift helper, XPC packaging and multi-profile registry are implementation proposals that must be tested on a real Mac.

## S06 — Chrome page observation

[Content scripts](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts)

Supports permitted DOM access and communication with the extension. Provider-specific status interpretation and its reliability are not guaranteed by this capability.

## S07 — Apple Liquid Glass

[Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

Documents glass grouping and related-view morphing. The requested full capsule-to-pane transition, window geometry, hit testing and supported OS minimum need a native prototype and SDK check.

## S08 — Apple destination links

[Allowing apps and websites to link to your content](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content)

Explains app/web association for universal links. It does not guarantee that another provider exposes any particular chat link or switches accounts on navigation.

## S09 — OpenAI desktop chat links

[Commands and deep links](https://learn.chatgpt.com/docs/reference/commands)

Documents chat deep links for the described desktop product. Installed product/version behavior, account handling, discovery and status must be tested separately. Do not infer universal access to consumer chat history from an API or CLI integration.

Reviewed again 2026-10-08 (page: [Commands for the desktop app](https://learn.chatgpt.com/docs/app/commands)): the app keeps the `codex://` scheme, and `codex://threads/<thread-id>` opens an existing local Codex thread by its technical ID. No documented link opens a ChatGPT web conversation and no documented way lists thread IDs, so Porter cannot offer this link without a user-supplied ID.

## S10 — MCP resources

[Resources, specification revision 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/server/resources)

Provides the resource concept for contextual data. Used for conceptual design only; this is a versioned reference, not a claim that it is the newest release. Select a compatible current protocol/SDK during TASK-070.

## S11 — MCP tools

[Tools, specification revision 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)

Provides the tool concept for retrieval/actions. Our `project_memory.*` names and payloads are proposed application contracts. Tool annotations are not a replacement for implemented access enforcement.

## S12 — Claude desktop links

[Open Claude desktop with a link](https://support.claude.com/en/articles/14729294-open-claude-desktop-with-a-link), accessed 2026-10-08.

Documents the `claude://` scheme for macOS, Windows and Linux: `claude://claude.ai/chat/{conversation-id}` opens an existing chat, `claude://claude.ai/new` (optional `q` prefill) starts one, and a missing or invalid ID opens the recent chats list. The article names no minimum app version and states no account rules. Porter uses only the existing-chat form; the prefill form puts text into a prompt and is out of scope for R1.

## S13 — Claude Code in VS Code

[Use Claude Code in VS Code](https://code.claude.com/docs/en/vs-code) and [Launch sessions from links](https://code.claude.com/docs/en/deep-links), accessed 2026-10-08.

The extension registers `vscode://anthropic.claude-code/open` with optional `prompt` (pre-fills, never sent) and `session` (resume a session ID). The session must belong to the workspace open in the VS Code window that receives the link, which is whichever window is focused; if it is not found, a fresh conversation starts instead; if it is already open in a tab, that tab is focused. A separate `claude-cli://open` scheme opens a terminal session. No page documents a way to list open sessions or to target a specific VS Code window.

## S14 — Claude Code authentication and credential use

[Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance), accessed 2026-10-08.

Subscription OAuth is intended for Anthropic's own applications. Developers building products must use API keys; Anthropic "does not permit third-party developers to offer Claude.ai login into their own applications, or to route requests through Free, Pro, or Max plan credentials", and developers "may not collect, store, or intermediate Claude.ai credentials or session tokens". This rules out any Porter feature that signs in to a Claude account or reuses its tokens to list sessions. No documented API lists a user's claude.ai conversations or local Claude Code sessions.

## S15 — Claude Code hooks

[Hooks reference](https://code.claude.com/docs/en/hooks), accessed 2026-10-08 (the page was read in two parts; sections after about character 200,000 were not read).

Hooks run a user-configured command on events and receive JSON on stdin: `session_id`, `cwd`, `transcript_path`, `hook_event_name`, and event fields such as `notification_type` (values include `permission_prompt`, `idle_prompt`, `elicitation_dialog`, `agent_needs_input`). The events Porter uses are `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, `SessionEnd`. `UserPromptSubmit` input contains the full prompt text, and tool events contain tool arguments. A hook may set `"async": true` to run in the background. On exit 0, stdout of `UserPromptSubmit` and `SessionStart` hooks is added to Claude's context, so Porter's hook prints nothing; a non-2 non-zero exit is reported as a failure, so it always exits 0. Hooks inherit the parent environment, which includes `CLAUDE_CODE_ENTRYPOINT`. The page says hooks fire in IDE extensions but does not name the VS Code extension specifically, so that is verified by use.

## Product evidence

The user supplied a product analysis of One and reference screenshots, then explicitly narrowed scope during the 2026-10-08 conversation. Those messages establish intent, not proof of any integration. This pack records the relevant requirements in memory/FACTS.md without copying private conversations or embedding the reference product's marketing claims as our own capabilities.

## Verification still required

CloudKit is a proposed transport, and no detailed CloudKit privacy/latency/revocation guarantee is established here. Research the current official Apple documentation and prove the required behavior in TASK-030. Signing, minimum OS, browser-store distribution and native API availability also need current verification at implementation time.
