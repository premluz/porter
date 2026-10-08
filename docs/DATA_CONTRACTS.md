---
id: "DOC-DATA"
type: "spec"
title: "Data model and protocol contracts"
status: "draft"
updated: "2026-10-08"
owner: "project-maintainer"
tags: ["area/identity", "area/browser", "area/macos", "area/ios", "phase/r1"]
summary: "Conversation identity, status evidence, IPC, and later send semantics."
related: ["DOC-ARCHITECTURE", "DOC-SECURITY", "DOC-VALIDATION"]
---

# Data model and protocol contracts

All structures below are proposed v1 contracts. Translate them into JSON Schema plus Swift/TypeScript types during TASK-012. Field names are normative for that first implementation plan; constraints must be tested, not assumed.

Bridge payloads (hello, hello.ack, inventory.snapshot, destination.upsert/remove, heartbeat, activate.request, error) are defined in `packages/contracts/schemas/bridge-payload.schema.json`; `activate.result` reuses `activation-result.schema.json`. `status.observed` has no payload contract yet and is refused by the registry until a status adapter is verified (TASK-013). A connector reports only tabs its adapter recognizes, never page text.

Implemented 2026-10-08 (TASK-012): JSON Schemas in `packages/contracts/schemas/`, shared fixtures in `packages/contracts/fixtures/`, Swift models in `packages/ConversationCore`. TypeScript types will be generated when the extension exists. Deviations from the table below: `Destination.kind` comes from `locator.kind` rather than being stored twice; `capabilities` is an array of `{name, supported, reason?}`; `ActivationResult` and `ContextLink` (ADR-004) have their own schemas.

## Entities

| Entity | Fields and rules |
| --- | --- |
| Conversation | `id: UUID`, `provider`, `providerConversationId?`, `accountScopeId?`, `workspaceScopeId?`, `title`, `createdAt`, `lastObservedAt`, `revision` |
| Destination | `id`, `conversationId`, `kind: browserTab/desktopLink/mobileLink`, `deviceId`, `connectorId?`, `identityEpoch`, `locator`, `capabilities`, `lastVerifiedAt`, `revision` |
| Connector | `id`, `deviceId`, `providerType`, `profileAlias?`, `installationId`, `connectionEpoch`, `protocolVersion`, `adapterVersions`, `connectedAt`, `lastHeartbeatAt` |
| AccountScope | `id`, `provider`, `evidence: providerReported/userLabel/unknown`, `opaqueProviderAccountId?`, `displayLabel?`, `verifiedAt?` |
| StatusObservation | `id`, `destinationId`, `activity`, `attention`, `evidenceKind`, `observedAt`, `receivedAt`, `expiresAt`, `sequence`, `connectionEpoch`, `adapterVersion` |
| Preference | `conversationId/destinationId`, `pinned`, `pinOrder`, `hidden`, `revision`, `modifiedAt`, `modifiedByDeviceId` |
| Device | `id`, `platform`, `displayName`, `enrollmentStatus`, `lastSeenAt`, `revokedAt?` |
| MessagePreview (R3) | `id`, `conversationId`, `sourceMessageId?`, `role`, `excerpt`, `truncated`, `observedAt`, `expiresAt`, `sourceRevision` |
| SendIntent (R4) | `id`, `destinationId`, `expectedIdentityEpoch`, `expectedDestinationRevision`, `text`, `createdAt`, `expiresAt`, `deliveryState`, `idempotencyKey` |
| GeneratedSummary (R5) | `id`, `previewId`, `sourceRevision`, `text`, `generatedAt`, `model`, `processingLocation` |

Timestamps are UTC RFC 3339 strings at boundaries. Use monotonic clocks for local timeouts; do not trust a web page's clock. `revision` is a monotonically increasing service-owned integer per record, not a wall-clock timestamp.

## Identity and merging

- A provider conversation ID alone is not globally unique across providers or accounts.
- Verified canonical key: provider + confirmed account scope + workspace scope if meaningful + provider conversation ID.
- If account scope is unknown, keep connector/identity-epoch-scoped records. Duplicate-looking titles or URLs do not authorize cross-profile merging.
- Multiple destinations may point to one verified conversation. Preserve every route; a user can select a preferred destination.
- Browser locator: connector ID + connection epoch + tab ID, with current window ID as a hint. Retain a sanitized canonical conversation URL for explicit reopen.
- Native locator: bundle ID plus validated deep link and available account scope. A native link is not a guarantee of account switching.
- Mobile locator: supported URL or app deep link plus account requirement label. No browser tab IDs or desktop local paths are mobile destinations.
- Unsaved/new chats get temporary conversation IDs. Reconcile only when the adapter observes a stable route in the same validated identity context.

## Status axes

| Axis | Values | Meaning |
| --- | --- | --- |
| activity | `working`, `idle`, `unknown` | Observable activity of this conversation |
| attention | `needsUser`, `newResponse`, `none`, `unknown` | Whether user attention is explicitly evidenced |
| reachability | `connected`, `disconnected`, `unavailable` | Whether the owning connector is reachable |
| freshness | `fresh`, `stale`, `unknown` | Whether the observation can still be relied on |
| evidenceKind | `providerEvent`, `domSignal`, `userAcknowledged`, `none` | How the observation was obtained |

Display precedence for fresh observations: needsUser, working, newResponse, idle, unknown. Disconnected/stale is a secondary badge and suppresses any claim of current activity. Preserve the last-known state in detail with its age. Do not use a probabilistic confidence percentage without calibrated evidence.

Proposed observation expiry: 15 seconds for actively watched DOM signals, 60 seconds for inactive observed tabs; the adapter must refresh evidence or mark stale. Provider events can define different freshness rules in their adapter contract. Frozen/discarded tabs immediately lose live-observation capability until resumed. These intervals require energy/performance testing.

## Adapter interface

```ts
interface ConversationAdapter {
  provider: string;
  adapterVersion: string;
  matches(url: URL): boolean;
  readIdentity(context: PageContext): IdentityResult;
  readTitle(context: PageContext): string | null;
  observe(context: PageContext, emit: (o: Observation) => void): () => void;
  capabilities(context: PageContext): CapabilitySet;
}
```

`PageContext`, `IdentityResult`, `Observation`, and `CapabilitySet` are schema types to implement in TASK-012. Adapter output contains normalized data, never DOM HTML or executable expressions. `observe` must release observers on route change/unload. Do not scrape full message text to derive R1 state.

Capabilities have a support flag and an optional reason: `discover`, `observeStatus`, `activate`, `openMobile`, `readPreview`, `draft`, `send`. Capability presence is per destination and version, not a blanket provider promise.

## Versioned local envelope

```json
{
  "protocolVersion": "1.0",
  "messageId": "example-uuid",
  "connectorId": "example-connector",
  "connectionEpoch": "example-epoch",
  "sequence": 12,
  "type": "destination.upsert",
  "sentAt": "2026-10-08T07:00:00Z",
  "payload": {}
}
```

Example values are illustrative, not real telemetry. Enforce a 64 KiB application envelope limit for R1 metadata; bounded title/URL lengths; enumerated types; and rejected unknown major versions. Negotiate additive minor-version fields. Read native messaging frames from the browser runtime's documented framing; reject oversized frames before decoding.

Message types: `hello`, `hello.ack`, `inventory.snapshot`, `destination.upsert`, `destination.remove`, `status.observed`, `heartbeat`, `snapshot.request`, `activate.request`, `activate.result`, `error`. Activation results return request ID and destination revision. Deduplicate `(connectorId, connectionEpoch, sequence)` and message IDs within a bounded window. Never replay activation on reconnect automatically.

## Activation results

`activated`, `targetGone`, `targetChanged`, `accountChanged`, `connectorOffline`, `permissionDenied`, `unsupported`, `versionMismatch`, `timeout`, `failed`. A timeout may mean a focus request happened but acknowledgment was lost; do not fabricate certainty. Explicit user retry is acceptable for navigation after revalidation.

## Sync payload

Use a separate allowlisted DTO: conversation display ID/title, provider, user alias, status observation with age, source device label, approved mobile destination, pins, record version, and tombstone. Exclude credentials, raw DOM, full browser history, local file paths, session cookies, and message bodies in R2. Cap batch sizes and reject snapshots from revoked source devices.

Device observations are append/update by their owner; read acknowledgments are per device. Resolve preference conflicts using record version when comparable, otherwise `(modifiedAt, deviceId)` with explicit documented clock caveat. Tombstones survive at least the maximum offline retention; proposed 30 days, with full resync required for devices returning later.

## Composer contract — future only

A draft and a sent message are distinct. States: `draft`, `queued`, `dispatching`, `acceptedBySource`, `failed`, `unknownOutcome`, `expired`, `cancelled`. R4 does not imply a provider offers idempotent sending: if no provider acknowledgment/key support exists, never guarantee exactly-once delivery. Do not retry `unknownOutcome`; show the original chat for inspection.

Require explicit user Send, validated target/account/revision, payload limits, and bounded intent lifetime (proposed two minutes). Disable offline sending initially. A source's “yes” approval prompt must be handled in that source UI, not transformed into a universal approve control. No replay after account change, revocation, or reconnect.
