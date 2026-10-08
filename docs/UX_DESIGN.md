---
id: "DOC-UX"
type: "spec"
title: "UX and visual design specification"
status: "draft"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/ux", "area/macos", "area/ios", "phase/r1", "phase/r2"]
summary: "Interaction flows, liquid-glass motion, and accessibility behavior."
related: ["DOC-SCOPE", "DOC-DATA", "DOC-VALIDATION"]
---

# UX and visual design

## Product promise

“Your conversations, close at hand.” Working copy only. The product helps a user see which conversations need attention and return to the right place. It must remain useful for a quiet ordinary chat with no task status.

## Mac surfaces

| Surface | Contents | Behavior |
| --- | --- | --- |
| Edge capsule | Small set of conversation dots; overflow count; expand affordance | Dots are direct shortcuts; expand control opens the full pane |
| Hover label | Title, provider, profile/account alias, status text | Appears after a brief delay; does not steal focus |
| Expanded pane | Search, Pinned, Open/Recent, source badge, status and age | Stable order during interaction; keyboard selection |
| Connection settings | Browser profiles, native-link sources, permissions, retention | Clear connected/limited/disconnected explanations |
| Menu-bar fallback | Open pane, pause observation, settings, quit | Remains accessible if edge positioning is inconvenient |

Proposed sizing: capsule 36–44 pt wide; expanded pane 336–400 pt wide; rows 52–64 pt high; cap height to visible screen bounds. All values are design starting points, not locked implementation constants. Support left/right edge, adjustable vertical position, and display choice. Avoid a full-height wall of glass.

Limit collapsed shortcuts to approximately 5–7; use overflow for the rest. Selected title appears in tooltip/expanded view; do not expect people to recognize a dozen unlabeled dots. Provider marks and meaningful labels complement status color.

## Main flow

1. User connects a browser profile; currently open supported chats appear.
2. User can pin, hide, rename a local display label, or select a preferred destination.
3. Working state is visible without opening the pane where supported.
4. Click a dot/row or press Return to activate the original chat; pane collapses after successful handoff.
5. If activation fails, keep the pane open and offer a concrete recovery: reconnect source, open saved link in original profile, or remove the shortcut.

Hover alone must not expand a large pane unexpectedly. Use click, global shortcut, or a deliberate edge gesture if later tested. Escape reverses opening/closing from the current visual state; it must not flash a separate window.

## Ordering and attention

Pinned order is user-controlled. Open/recent is sorted by relevance or recency only while inactive; freeze rows under pointer and keyboard navigation. New attention changes a badge rather than moving a target beneath the cursor. Provide an optional Needs you filter. Avoid notification overload: R1 is quiet by default with explicit opt-in for attention alerts.

## Status language

| Label | Visual cue | Interpretation |
| --- | --- | --- |
| Working | Restrained animated dot/ring | Fresh source evidence of current activity |
| Needs you | Warm amber + icon/text | Explicit question or approval awaiting input |
| New response | Subtle accent + unread marker | New response observed, not a completed-project claim |
| Idle | Neutral solid dot | Observed inactive state |
| Unknown | Neutral outlined dot | Source does not expose reliable status |
| Last seen… | Secondary age/offline cue | Cached observation; no live claim |

Pair color with shape, text, and accessibility labels. Do not animate stale or disconnected working states as if live.

## Visual language

Use system typography, SF Symbols where suitable, generous alignment, short labels, and restrained hierarchy. Glass belongs primarily to the outer pane and controls. Content rows remain visually calm, with enough backing contrast to read over bright windows or complex wallpaper. Avoid nested glass cards, heavy outlines, neon, exaggerated reflections, and decorative ripple over text.

Use semantic colors and spacing tokens: `surface.panel`, `surface.contentBacking`, `text.primary`, `text.secondary`, `border.subtle`, `status.working`, `status.attention`, `status.unread`, `status.unknown`; spacing scale 4/8/12/16/24 pt. Actual color values adapt to appearance and contrast settings. These are design tokens, not claims that every token is an Apple API.

## Liquid transition specification

The capsule expands from its anchored edge into one continuous panel silhouette. Corners and curvature interpolate; the visual mass appears connected. Proposed duration 220–320 ms with a critically damped or lightly settling spring. Content reveals slightly after enough width exists; retain text at final scale to avoid stretching letters. Closing returns to the same capsule anchor. Interruptions reverse from current presentation state.

Use native SwiftUI Liquid Glass APIs on supported OS versions. `GlassEffectContainer` and matched glass identities support related-shape transitions [S07](SOURCES.md); the large capsule-to-pane geometry is a prototype question. Keep both states in one AppKit panel during the transition so native-window boundaries do not clip the effect. Resize the host window and update hit testing deliberately; transparent panel regions must not intercept unrelated desktop input. If native morphing fails the visual criteria, use a native material plus smooth shape/size transition before considering a custom rendering layer.

Test multi-display scale changes, menu-bar/Dock overlap, full-screen Spaces, Mission Control, inactive apps, and screen recording. Do not promise glass will sample all behind-window content identically across every configuration.

## Accessibility

- VoiceOver row label includes title, provider, source alias, status, and age.
- Full keyboard flow: open, search, arrows, Return, Escape; expose the configured shortcut in UI.
- No focus stealing while a source status changes. Hover labels never take keyboard focus.
- Reduce Motion uses a brief fade or immediate transition, with no elastic movement.
- Reduce Transparency uses an opaque semantic surface.
- Support increased contrast and text scaling where appropriate; no fixed heights that clip larger text.
- On iPhone, use at least 44 pt interactive targets and Dynamic Type.

## iPhone companion

R2 uses a normal SwiftUI app with a conversation list, source-device context, freshness, and a details sheet. The Mac edge overlay does not become a system-wide phone overlay. Tap a supported mobile destination to open it. Mac-only entries show that limitation, while preserving useful last-seen context.

First-time mobile flow: opt into sync on Mac; sign into the required sync account on phone; enroll/select device; choose shared metadata; show a sample conversation. Explain that source-provider logins are independent from synchronization. If an account is wrong on phone, use the provider's own account switcher; do not silently open a different conversation.

## Future preview/composer

Preview expands within a row/detail, shows a verbatim bounded excerpt, and includes Open original. Composer always shows a fixed target chip with provider, title, account alias, and device. Changing target preserves draft only with explicit user action. Enter/send behavior must be consistent; show accepted/failed/unknown delivery status. No keyboard shortcut should accidentally approve an agent action. Generated summary is visually labelled and expandable to its source excerpt.

## Design review acceptance

Review a recording of opening, interrupted close, hover, failed activation, unknown status, and source disconnect on both dark and light complex backgrounds. A visual mockup alone does not establish desktop behavior. Measure keyboard speed and wrong-target activation in a small personal-use trial before optimizing decoration.
