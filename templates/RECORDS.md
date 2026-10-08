---
id: "DOC-TEMPLATES"
type: "template"
title: "Reusable record templates"
status: "template"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/memory", "area/quality", "phase/foundation"]
summary: "Small templates for tasks, evidence, decisions, plans, and handoffs."
related: ["DOC-MEMORY", "DOC-TASKS"]
---

# Record templates

Copy only the needed template into its canonical location. Allocate a real unique ID, update metadata, link it from the relevant task/index, and regenerate the catalog. Placeholders below are not live records.

## New document metadata

```yaml
---
id: "DOC-<UNIQUE-NAME>"
type: "spec"
title: "<Descriptive title>"
status: "draft"
updated: "YYYY-MM-DD"
owner: "<Contributor>"
tags: ["area/product", "phase/r1"]
summary: "<What question this document answers.>"
related: ["DOC-SCOPE"]
---
```

## Task detail

```markdown
### TASK-<NNN> — <Observable outcome>
- Owner / claim time:
- Status: todo
- Depends on:
- Requirements:
- Paths likely to change:
- Implementation steps:
- Acceptance: <Concrete input, action, expected result.>
- Verification command/manual scenario:
- Evidence / limitations:
```

TASKS.md remains the owner of status; detailed task text can live in its plan.

## Progress checkpoint

```markdown
## LOG-<YYYYMMDD>-<NNN> — <Outcome>
- Date/time and author:
- Tasks / tags:
- Changed:
- Verified: <Command/scenario and observed result.>
- Not verified: <Environment or remaining uncertainty.>
- Evidence: <Relative path or commit; redact sensitive content.>
- Decisions:
- Next action:
```

## Decision record

```markdown
# ADR-<NNN> — <Decision>
- Status: proposed | accepted | superseded
- Date / owner:
## Context
## Decision
## Alternatives and tradeoffs
## Evidence / validation needed
## Consequences
## Revisit trigger
## Supersedes / superseded by
```

## Execution plan

```markdown
# PLAN-<NNN> — <Outcome>
## Purpose
## Current context and constraints
## Progress
## Implementation sequence and real paths
## Contracts and dependencies
## Validation and acceptance
## Recovery and repeatability
## Discoveries
## Decisions (ADR links)
## Outcomes and remaining work
```

## Durable fact

```markdown
## FACT-<NNN> — <Finding>
- Class: user_requirement | source_documentation | verified_test
- Statement:
- Source / exact environment:
- Observed date:
- Tags:
- Review trigger:
```

## Handoff

```markdown
# Handoff
- Current task/owner:
- Goal:
- What changed:
- What is proven:
- What remains uncertain:
- Source paths and decision IDs:
- Commands/results:
- Immediate next action:
```

A handoff should help the next agent act, not reproduce the entire conversation or hidden reasoning.
