---
id: "ADR-006"
type: "decision"
title: "Native-first sources, optional enhancers"
status: "proposed"
updated: "2026-10-09"
owner: "project-maintainer"
tags: ["area/macos", "area/browser", "area/identity", "area/distribution", "phase/r1"]
summary: "v1 is one installable app that observes browsers, desktop apps and editors natively; the browser extension and editor companion become optional enhancers behind the same adapter boundary."
related: ["ADR-002", "ADR-005", "PLAN-002", "DOC-ARCHITECTURE"]
---

# ADR-006 — Native-first sources, optional enhancers

- Date: 2026-10-09.
- Status: proposed; the native routes are unproven until the spikes in PLAN-002 report.
- Owner: Prem (direction), assistant (feasibility).

## Context

ADR-002 made a per-profile Chrome extension the way to see and activate browser tabs. Prem's direction for v1: ship one app package that installs and works on its own, reading VS Code, the ChatGPT desktop app, the Claude desktop app and browser chats. The first set is Chrome, VS Code, Claude and ChatGPT, but other models, browsers and coding environments are expected, so the structure must be modular. Users of other browsers cannot be asked to install an extension, and an extension is install overhead. The extension (v0.1) stays as it is.

## Decision

1. **Two source tiers behind one adapter boundary.**
   - Native tier, in the app with no extra install: operating-system routes (Apple Events scripting of browsers that support it, the Accessibility API for desktop apps, documented deep links, `NSWorkspace`). This is the primary route.
   - Enhancer tier, optional and installed by the app's setup assistant: the Chrome extension per profile (v0.1) and the VS Code companion. They add what native routes cannot: profile identity, last-used time, working state, exact tab identity.
2. **Modularity along the axes that already exist.** A *host connector* is how one application is observed and activated (Chrome via scripting, Chrome via extension, Safari, VS Code, ChatGPT app, Claude app). A *provider recognizer* turns a URL or title into provider and conversation identity (claude, chatgpt, later others). Adding a model, a browser or an editor must be a new adapter that does not change the registry, the panel model or the contracts.
3. **Honest identity.** The native tier often cannot say which browser profile a tab belongs to. Such a destination reports profile as unknown, and two tabs of the same conversation across profiles are reported as ambiguous, not guessed. The enhancer tier removes the ambiguity where it is installed. No credential or cookie is read.
4. **VS Code keeps its companion as the primary route.** That is my assumption from Prem's direction, which was aimed at browsers: a companion extension is VS Code's supported API and installs with one command from the bundle. An Accessibility fallback is assessed, not planned.
5. **One package.** The app bundle carries the helpers, the native-messaging registration, the bundled enhancers and a first-launch checklist that shows each source as ready or not (TASK-027, TASK-084).

## Consequences

- ADR-002's "extension per profile" becomes the secondary route; its native-host and bridge work stays and is reused by the enhancer tier.
- Permissions become part of the product: Automation (per browser) and Accessibility (desktop apps) are requested and explained by the setup assistant, and a refusal leaves that source visibly off, never silently empty.
- Anything the native routes cannot deliver (recency, working state) is shown as Unknown unless an enhancer supplies it.

## Open questions (answered by the PLAN-002 spikes)

Whether Chrome's scripting interface can list and focus tabs reliably and across profiles; whether the ChatGPT and Claude desktop apps expose their conversation lists to Accessibility; what recency can be inferred without an enhancer; whether Chrome accepts an externally installed extension (TASK-081 to TASK-083).
