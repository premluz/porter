---
id: "DOC-SECURITY"
type: "spec"
title: "Security and privacy boundaries"
status: "draft"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/security", "area/identity", "area/browser", "area/ios", "phase/r1", "phase/r2"]
summary: "Concrete data access and destination-protection requirements."
related: ["DOC-SCOPE", "DOC-DATA", "DOC-VALIDATION"]
---

# Security and privacy boundaries

## Accurate product claim

The switcher does not decide which agent actions to approve. R1 reads selected metadata and observed state to provide navigation. That reduces the action surface but does not remove privacy and destination-integrity responsibilities. A later composer sends instructions which can cause the original agent to act.

## Capability and data matrix

| Capability | Data accessed | Action surface | Release |
| --- | --- | --- | --- |
| Pinned shortcut | User-supplied title/link | Open intended destination | R1 |
| Web discovery | Supported tab URLs, titles, tab/window locators | Activate selected tab/window | R1 |
| Status | Minimal provider-specific UI/event signals | Update local indicator | R1 |
| Native sources (ADR-006) | Chrome and Safari: titles and URLs of provider tabs only, by Apple Events, incognito skipped. Desktop apps: titles of sidebar entries within the leftmost 300 points of the window, by Accessibility. Codex: its thread list (id, title, last update) and, from each session file, only the folder, the surface that made it and whether it is a helper thread; the rest of the file is never parsed or kept | Activate the selected tab, press the selected sidebar entry, or open a thread through its owner's link | R1 |
| Phone sync | Selected normalized metadata | Store/sync to enrolled device | R2 |
| Preview | Latest selected message excerpt | Read/cache/display content | R3 |
| Composer | User draft, exact target context | Send through supported destination | R4 |
| Summary | Selected source excerpt | Local inference or disclosed provider request | R5 |

No microphone, screen capture, full-disk access, cookie import, or provider credential extraction is needed for baseline browser discovery/navigation. Desktop UI automation, if pursued later, may need Accessibility or Automation access; gate it by that optional adapter rather than requesting broad access at first launch.

## Browser permissions

Request supported provider host permissions and native messaging. Choose the minimum tab metadata permissions during the spike; do not request all-site read access merely for convenience. Content scripts operate only on allowed origins and routes. Incognito is disabled by default. The user enables each profile and can disconnect it independently.

The service worker verifies the sender and derives the tab identity itself; a page cannot supply an arbitrary tab ID to control another tab. Reject cross-origin redirects, oversized data, unrecognized event types, and provider strings masquerading as host commands. Render titles as text, never HTML.

## Native bridge

Allowlist the packaged extension ID in the native host manifest. Separate development extension IDs from production. Authenticate the signed native helper at the local IPC boundary; do not treat a JSON `connectorId` as authentication. Use a per-user service with no root privileges. Establish bounded framing, timeouts, version negotiation, and disconnect cleanup. Test installed-package behavior, not only a debug run.

Only `activate` is a navigation command in R1. Do not expose arbitrary shell, AppleScript, JavaScript, file-read, or generic URL-open commands over the browser bridge. Provider-specific URLs must pass an allowlist and route validator; reject `file:`, `javascript:`, unexpected custom schemes, and attacker-controlled app arguments.

## Destination integrity

Revalidate the locator and identity epoch at activation. A background page cannot change its title to cause another account's conversation to be targeted. An unknown account remains unknown. Switching provider accounts invalidates derived identity; if detection is unreliable, document the limitation and prevent stronger account guarantees.

## Data retention

Proposed R1 defaults: recent metadata seven days, pins until removed, status history limited to latest observations, diagnostic logs seven days with opaque IDs and error codes. Titles and full URLs are excluded from diagnostics by default. “Clear history” deletes recent records; removing a source offers deletion of its pins too. Sync tombstones handle deletion propagation in R2.

R3 excerpt cache defaults to 24 hours and is disabled until opted in. Enabling previews does not authorize summaries or cloud model processing. Deleting a preview deletes derived summaries. Never include source conversation bodies in project memory or automated bug reports.

## Mobile synchronization

Use transport encryption and the chosen service's supported protections. CloudKit private database is proposed for a same-Apple-account companion; do not market custom end-to-end encryption unless the actual record fields, key model, and implementation have been verified. Private database scope alone is not a claim that the service cannot read every field.

The R2 spike must establish enrollment, data selection, revocation, sign-out behavior, offline retention, and deletion semantics. If stronger cryptographic device exclusion is required than the transport supports, design application-level payload encryption and key rotation or choose another transport. This is an architecture change, not a claim already fulfilled.

## Composer and summary extensions

Composer adds an action capability. Require an explicit target and Send gesture, revalidate the destination immediately before dispatch, reject expired intents, and show uncertain delivery. Keep approvals in the source tool. Do not resend after timeout unless a source supports reliable deduplication and the observed result permits retry.

Summary content is untrusted source data. Summarization must not route tasks, approve actions, or execute instructions found in the excerpt. Document exactly what is sent to an external provider and allow disabling that processing independently.

## Concrete failure cases to test

1. A tab navigates between row selection and activation.
2. Two profiles have identical chat titles and cloned connector IDs.
3. The original account signs out while the pane is open.
4. Malformed/oversized IPC and an unapproved extension try to reach the service.
5. An adapter emits a title containing HTML, Markdown links, or command-looking text.
6. Phone loses connectivity, source device is revoked, and old snapshots arrive later.
7. A send acknowledgment is lost after a future composer dispatch.

These are acceptance cases for the scoped behavior, not a separate approval process for routine development.
