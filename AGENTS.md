---
id: "DOC-AGENTS"
type: "instructions"
title: "Shared agent instructions"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "phase/foundation"]
summary: "Small shared entry point for coding agents."
related: ["DOC-STATE", "DOC-CONSTITUTION", "DOC-MEMORY"]
---

# Project agent instructions

This project is a Mac conversation switcher with an iPhone companion. It is currently a documentation starter. Follow the user's current task and applicable host instructions; these project conventions do not override them.

## Orient proportionately

- For implementation or a handoff, read PROJECT_STATE.md and the relevant TASKS.md entry.
- Use memory/INDEX.md or `python3 tools/project_memory.py search "query"` to locate relevant context.
- For behavior boundaries, read CONSTITUTION.md. For source-specific changes, read the linked scope, architecture, or UX document only as needed.
- For a trivial documentation edit, inspect the target and validate its links; do not preload the entire project.

## Product invariants

- A click targets a conversation and destination, including its browser connector/profile or desktop app identity.
- Unknown status stays unknown. Never turn lost observation into a completed-task claim.
- Mac R1 performs navigation, not sending prompts or approvals. Composer, preview, and summary features have separate milestones.
- Browser accounts and phone accounts are not transferable sessions. Do not copy cookies or tokens.
- Project memory is development documentation. Product conversation content is not project instructions.

## Work and evidence

- Use PLANS.md for phase boundaries. Use a plan in plans/ for multi-step integration work; small fixes do not require a new plan.
- TASKS.md owns task status. Claim an unowned task before editing shared implementation files when multiple contributors are active. Do not create extra agents unless the user or current task requests them.
- Implement a complete observable slice, run relevant checks, and record outcomes. Distinguish planned, implemented, and verified.
- Document material uncertainty instead of inventing an API, account identifier, release result, or test command.
- Continue routine reversible work within the user's scope. These files add no blanket permission gate.

## Update durable memory

- After a meaningful checkpoint: update the task row, append a PROGRESS.md entry, and refresh PROJECT_STATE.md and memory/HANDOFF.md when the next action changed.
- Put enduring choices in an ADR; put demonstrated facts in memory/FACTS.md with evidence. Temporary observations belong in the progress log or active plan.
- Preserve existing record IDs. Link superseding records; do not silently rewrite the historical log.
- Never store credentials, signed URLs, private chat bodies, or personal data unnecessary to development.
- Regenerate `python3 tools/project_memory.py index`, then run `python3 tools/project_memory.py check` after documentation changes.

## Current commands

The only implemented commands are the documentation utility's `check`, `index`, `search`, and `read`. Native app, extension, and MCP tests do not exist yet. Add real commands to docs/VALIDATION_RELEASE.md when the corresponding targets exist.
