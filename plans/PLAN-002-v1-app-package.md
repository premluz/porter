---
id: "PLAN-002"
type: "plan"
title: "v1: one installable app that reads every source"
status: "active"
updated: "2026-10-09"
owner: "project-maintainer"
tags: ["area/macos", "area/browser", "area/release", "phase/r1"]
summary: "Native-first source adapters, feasibility spikes, and the single app package with a setup assistant."
related: ["ADR-006", "ADR-002", "ADR-005", "DOC-PLAN", "DOC-TASKS"]
---

# PLAN-002 — v1 app package

## Purpose

Deliver Porter as one app that, once installed, finds and opens conversations in Chrome (then other browsers), VS Code (then other editors), the ChatGPT app and the Claude app, without requiring a browser extension. See ADR-006.

## Order

1. **TASK-080 — adapter boundary.** Name the two axes (host connector, provider recognizer) in the core and registry, and make the current Chrome-extension and VS Code connectors implementations of it without changing behavior. All current tests keep passing; this is the base for everything else.
2. **Spikes, each ending in a FACT with evidence and a go/no-go (no product code kept unless it passes):**
   - TASK-081: Chrome (and Safari) through Apple Events: list windows, tabs, titles, URLs; focus a given tab; behavior with two profiles; what the Automation permission prompt looks like.
   - TASK-082: ChatGPT and Claude desktop apps through Accessibility: window and sidebar titles, selecting a conversation, permission flow; Electron versus native.
   - TASK-083: VS Code: bundled companion install by command line; whether an Accessibility fallback is worth assessing; other editors (Cursor and similar) only noted.
3. **Build the native adapters that pass**, each behind the boundary, with the enhancers switching on automatically when present.
4. **TASK-084 — setup assistant**: first-launch checklist, permission requests with plain explanations, per-source on/off, "Get the Chrome extension" and "Install VS Code companion".
5. **TASK-027 — bundle, sign, notarize**: app, helpers, native-messaging registration, bundled enhancers, launch at login; clean-account install test.

## Rules for this plan

- A source that cannot be read stays Unknown or off; it is never reported as empty or finished.
- No page content, conversation text or prompts are read; only titles, URLs, window and tab identity.
- The Chrome-extension install route (external extension file versus unlisted Web Store) is decided from evidence in TASK-081.

## Progress

- [x] Direction recorded (ADR-006, this plan, TASK-080 to TASK-084).
- [ ] TASK-080 to TASK-084, then TASK-027.
