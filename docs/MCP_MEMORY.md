---
id: "DOC-MEMORY"
type: "spec"
title: "Project memory and MCP contract"
status: "active"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "area/mcp", "area/security", "phase/foundation"]
summary: "Portable Markdown conventions, tagging, retrieval, and future MCP tools."
related: ["DOC-AGENTS", "DOC-CLAUDE", "DOC-TASKS", "DOC-SOURCES"]
---

# Project memory and MCP contract

## What this setup implements

The pack implements canonical Markdown documents, short agent entry points, a stable-ID catalog, literal search with tag filters, ID-based reads, and a documentation validator. It does not implement or install an MCP server. A future MCP wrapper can call the same parser and retrieval functions. Any existing authorized filesystem MCP can read these files, but tags and IDs are project conventions, not automatically understood by every memory service.

Development memory and customer conversation data are separate systems. This catalog contains requirements, decisions, work records, and evidence for building the product. It must not index the user's ChatGPT/Claude conversations or browser credentials.

## Layers and ownership

| Layer | Canonical location | Role |
| --- | --- | --- |
| Agent behavior | AGENTS.md; CLAUDE.md imports it | Short instructions and context routing |
| Product invariants | CONSTITUTION.md | Enduring boundaries |
| Current checkpoint | PROJECT_STATE.md | What exists, limits, immediate next action |
| Design truth | docs/ and accepted decisions/ | Requirements, architecture, UX and rationale |
| Work truth | TASKS.md and plans/ | Status, dependency, execution context |
| Historical evidence | PROGRESS.md | Append-only events and results |
| Durable facts | memory/FACTS.md | Verified requirements/findings with provenance |
| Uncertainty | memory/QUESTIONS.md | Assumptions, risks, owners and resolution steps |
| Handoff | memory/HANDOFF.md | Small restart packet |
| Retrieval projection | memory/INDEX.md and catalog.json | Derived pointers, tags, revisions; never canonical |

Document status and task status are different. A spec can be `draft` while its authoring task is `done`; that does not mean the proposed application is implemented.

## Metadata convention

Every Markdown document uses the same restricted YAML frontmatter: each value is JSON syntax, which is valid YAML and parseable without a third-party package.

```yaml
---
id: "DOC-EXAMPLE"
type: "spec"
title: "Example document"
status: "draft"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/identity", "phase/r1"]
summary: "One-sentence retrieval description."
related: ["DOC-DATA"]
---
```

The example is a template, not a real indexed record. `id` is stable through renames. `related` contains existing document IDs. Use Markdown relative links for human navigation. Update `updated` only when substantive content changes. Do not add raw secrets or source conversation IDs to metadata.

Types: `index`, `instructions`, `constitution`, `state`, `spec`, `plan`, `tasks`, `log`, `memory`, `questions`, `handoff`, `decision`, `template`, `sources`.

Document statuses: `active`, `draft`, `proposed`, `accepted`, `superseded`, `complete`, `template`, `archived`. Task statuses are defined in TASKS.md. Tags describe subject and delivery phase; do not duplicate status in tags.

## Controlled tags

Areas: `area/product`, `area/ux`, `area/macos`, `area/browser`, `area/ios`, `area/identity`, `area/security`, `area/sync`, `area/quality`, `area/memory`, `area/mcp`, `area/release`.

Phases: `phase/foundation`, `phase/r0`, `phase/r1`, `phase/r2`, `phase/r3`, `phase/r4`, `phase/r5`.

Prefer 2–5 tags per file. Expand the vocabulary only for a real retrieval need and update this document and the validator together. Avoid synonyms such as `mac`, `macos-app`, and `desktop-mac` for the same area. No unrestricted hashtag accumulation.

## Record identifiers

Documents: `DOC-*`; decisions: `ADR-001` onward; execution plans: `PLAN-001` onward; tasks: `TASK-001` onward; requirements: `REQ-001` onward; tests: `TEST-001` onward; facts: `FACT-001` onward; questions: `Q-001` onward; risks: `RISK-001` onward; progress: `LOG-YYYYMMDD-NNN`.

Document IDs live in frontmatter; record IDs live in their canonical headings or table rows. Never recycle IDs. When renaming/moving, retain the ID and fix links. Templates use placeholders, not actual allocated IDs.

## Retrieval workflow

1. Resolve current scope from DOC-STATE for substantive work.
2. Search by plain language and exact tags, requesting a small number of results.
3. Read the relevant current document by stable ID; note its SHA-256 revision.
4. Follow related IDs for a needed decision or evidence. Do not preload all history.
5. Before editing, reread if the revision changed. Current source files outrank cached summaries.
6. After changes, regenerate the catalog and validate. If the catalog is stale, use the current files and rebuild it; never answer from stale snippets alone.

Retrieval priority: exact ID/title, tags/summary, lexical body match. Optional semantic search later must preserve source citations and revision checks. An embedding is a derived index, not permission to replace original facts.

## Local utility

```sh
python3 tools/project_memory.py index
python3 tools/project_memory.py check
python3 tools/project_memory.py search "profile" --tag area/identity --limit 5
python3 tools/project_memory.py read DOC-DATA --start 1 --limit 120
```

`search` and `read` scan current allowlisted Markdown directly, so they do not depend on stale catalog content. `index` regenerates the Markdown directory and catalog. `check` verifies frontmatter, tags, doc IDs, related references, local file links, task definitions/dependencies, and catalog freshness. It is not a full Markdown/YAML parser and does not validate web links or every prose ID reference. Its supported frontmatter format is intentionally restricted.

Run `python3 tools/test_project_memory.py` for behavioral checks covering retrieval, pagination, index rebuilding, invalid links/IDs, task cycles, and path confinement.

## Proposed MCP read interface

Resource URI form: `project://conversation-switcher/docs/{document_id}`. Expose only documents under this project root. Version pinning and SDK choice are implementation work in TASK-070; sources describe MCP concepts, not an already selected protocol release.

| Tool | Input | Output |
| --- | --- | --- |
| `project_memory.search` | `query`, optional `tags[]`, `types[]`, `status[]`, `limit`, `cursor` | Ranked IDs, paths, summaries, matching excerpts, revision hashes, next cursor |
| `project_memory.read` | `id`, `start_line`, `line_count`, optional `expected_revision` | Exact content, revision, line interval, more-content indicator |
| `project_memory.context` | `task_id`, optional `token_budget` | Task, relevant state/constraints/ADRs and pointers with citations |
| `project_memory.changes` | `since_revision` or `since_date`, `limit` | Changed records and progress entries; dates are advisory, hashes authoritative |

These tool names are proposed application APIs. A generic installed memory tool does not acquire them merely because the Markdown exists. Context assembly must include contradictions/unknowns, not only a confident summary. Bound responses, use deterministic pagination and include the catalog generation/revision for stable cursors.

Read result example:

```json
{
  "id": "DOC-STATE",
  "path": "PROJECT_STATE.md",
  "revision": "sha256:<actual-content-hash>",
  "start_line": 1,
  "end_line": 80,
  "has_more": false,
  "content": "<exact current source text>"
}
```

## MCP transport and boundaries

Start with local stdio owned by the developer's agent client. No hosted account or remote endpoint is required. The client explicitly configures the repository root; do not infer a root from arbitrary caller paths. Resolve canonical paths, reject traversal and symlink escapes, and allowlist only documentation paths. Do not expose `.env`, provider tokens, browser databases, customer previews, or application data.

MCP read-only annotations improve discoverability but are not enforcement. Enforce allowed operations in code. Resource availability does not guarantee that every client auto-loads it; AGENTS.md/CLAUDE.md and explicit calls provide the entry path. If remote HTTP is later required, use the then-current official authorization guidance and threat model; this pack does not install a remote server.

## Optional structured writes

Keep initial MCP read-only. Later mutations may include `append_progress`, `update_task`, and `propose_decision`. Require expected content revision, bounded schema, append-only event IDs, a serialized writer/lock, atomic file replacement, and an audit entry. Refuse conflicting writes instead of last-write-wins. A sequence of related file updates requires a transaction/journal or one reviewed Git change; per-file atomic rename alone is not multi-file atomicity.

Do not expose an unrestricted “write any file” memory tool. The actual filesystem path of an MCP resource is resolved by ID on the server. The user/task still governs authorization; project rules do not create a new approval requirement for already authorized routine edits.

## Handoffs and multiple agents

A handoff names task, owner, changed paths, proven behavior, relevant decisions, outstanding uncertainty, next concrete step, and test commands/results. No hidden reasoning transcript is required. Concurrent contributors should use separate worktrees or disjoint files and a single integration owner. Markdown task claims are not locks. Do not use auto-memory files as a shared concurrent database.

## Keeping memory small

AGENTS.md and CLAUDE.md should remain short. PROJECT_STATE.md targets one screen or two; the full specifications load on demand. Promote repeated verified findings into facts/ADRs. Archive old logs and superseded decisions without deleting references. Review stale facts at the next relevant task, especially provider/API compatibility. Private machine-local agent memory may retain a pointer to this root, but portable project memory stays here.
