---
id: "ADR-002"
type: "decision"
title: "Native Mac shell and browser connector"
status: "proposed"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/macos", "area/browser", "area/identity", "phase/r1"]
summary: "Proposed implementation split for native UI and browser-aware navigation."
related: ["DOC-ARCHITECTURE", "PLAN-001"]
---

# ADR-002 — Native app plus browser extension

- Date: 2026-10-08.
- Status: proposed technical default; feasibility validation pending.
- Owner: future platform implementer.

## Context

The user wants a global Mac edge pane with native Liquid Glass, while chats may be in multiple browser profiles or desktop tools. A plain URL cannot identify an already open tab in a particular profile.

## Decision proposal

Use SwiftUI/AppKit for the pane and native lifecycle. Use a Chrome MV3 extension in each enabled profile for tab discovery, source observations, and exact-tab activation. Use a native messaging helper and a signed local IPC boundary to a single registry service. Use manually pinned desktop deep links before attempting automatic desktop discovery.

## Why

This assigns browser ownership to browser APIs and desktop presentation to native UI. It preserves profile-local session context without credential transfer. A local single writer centralizes event ordering and state recovery.

## Alternatives

Native-only browser automation could reduce installation components but needs separate browser scripting/permission handling and may have weaker page observation. An extension-only product cannot supply the requested desktop-wide native pane. A webview wrapper would introduce separate provider sessions rather than track existing ones.

## Validation before acceptance

TASK-011 must prove two-profile activation, native-host installation, reconnection, and rejection of unapproved bridge messages. TASK-014 must prove the panel/morph approach. Select actual macOS minimum and service packaging based on TASK-010. Native messaging and a signed helper are documented building blocks, not evidence the proposed package already works.
