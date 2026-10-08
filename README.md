---
id: "DOC-README"
type: "index"
title: "Conversation Switcher — project entry"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/product", "area/memory", "phase/foundation"]
summary: "Entry point and navigation for the complete project pack."
related: ["DOC-STATE", "DOC-SCOPE", "DOC-MEMORY"]
---

# Conversation Switcher

Working project name; no final brand has been selected. Product owner: Prem.

A native Mac conversation switcher with an Apple-style glass edge pane. It gathers open, recent, and pinned conversations across supported web and desktop tools, shows status when observable, and returns the user to the original conversation. An iPhone companion follows. Previews, a composer, and summaries are staged extensions.

## Actual state

This is a documentation and project-memory starter, not a built application. The Mac app, extension, iPhone app, sync service, and MCP server have not been implemented or tested. The included Python utility validates and searches this documentation pack locally.

## Start here

1. [Current state](PROJECT_STATE.md) — what exists and the next action.
2. [Constitution](CONSTITUTION.md) — product and engineering boundaries.
3. [Technical scope](docs/TECHNICAL_SCOPE.md) — requirements and release boundaries.
4. [Work plan](PLANS.md) and [task ledger](TASKS.md) — sequence, dependencies, acceptance.
5. [First implementation plan](plans/PLAN-001-feasibility.md) — prove the integrations on a Mac.

Agents enter through [AGENTS.md](AGENTS.md); Claude Code also has a thin [CLAUDE.md](CLAUDE.md). Both route to the same project truth. Read relevant documents, not the entire pack on every turn.

## Topic map

| Question | Document |
| --- | --- |
| How should it look and behave? | [UX and visual design](docs/UX_DESIGN.md) |
| How do the components connect? | [Architecture](docs/ARCHITECTURE.md) |
| What exactly is a conversation, destination, or status? | [Data and protocol contracts](docs/DATA_CONTRACTS.md) |
| What can the app read or send? | [Security and privacy](docs/SECURITY_PRIVACY.md) |
| What proves a release works? | [Validation and release](docs/VALIDATION_RELEASE.md) |
| How do agents retrieve and maintain memory? | [Memory and MCP contract](docs/MCP_MEMORY.md) |
| What is known, assumed, or unresolved? | [Facts](memory/FACTS.md), [questions](memory/QUESTIONS.md) |
| Why were choices made? | [Navigation decision](decisions/ADR-001-navigation-first.md), [platform decision](decisions/ADR-002-native-and-extension.md), [mobile proposal](decisions/ADR-003-mobile-sync.md) |
| What happened and where do I resume? | [Progress](PROGRESS.md), [handoff](memory/HANDOFF.md) |
| Which conventions are official? | [Sources and attribution](docs/SOURCES.md) |
| Where is every document indexed? | [Memory index](memory/INDEX.md) |

## Use locally

Extract this folder into the intended repository root. Preserve its relative paths. Python 3.10+ is required only for documentation tooling:

```sh
python3 tools/project_memory.py check
python3 tools/test_project_memory.py
python3 tools/project_memory.py search "account" --tag area/identity
python3 tools/project_memory.py read DOC-STATE
python3 tools/project_memory.py index
```

`index` rebuilds the derived Markdown index and JSON catalog after edits. `check` detects broken local links, duplicate IDs, invalid tags, and a stale catalog. No third-party Python packages are required. This utility is not an MCP server.

## Keep memory portable

Markdown files are authoritative. `memory/catalog.json` is derived and replaceable. A future MCP adapter can expose the same documents with stable IDs and revision hashes. Machine-local agent memory may point here; it must not become a competing source of project decisions.

All source paths for the planned application are proposals until implementation creates them. Application commands in the work plan are intended future commands, not claims that build targets already exist.
