---
id: "DOC-CLAUDE"
type: "instructions"
title: "Claude Code entry point"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "phase/foundation"]
summary: "Routes Claude Code to the shared project instructions."
related: ["DOC-AGENTS"]
---

# Claude Code entry point

@AGENTS.md

Use the shared instructions above. PROJECT_STATE.md is the current checkpoint; memory/INDEX.md routes to deeper context. Read these files when the task needs them.

Keep durable project decisions in this repository. Machine-local auto memory may contain short pointers to document IDs, but must not duplicate the task board, source of truth, or full progress log.

If a client does not expand file imports, open [AGENTS.md](AGENTS.md) explicitly. No personal Claude configuration or MCP connection is installed by this pack.
