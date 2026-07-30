# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                              : DEV
Controlled malformed probes              : COMPLETED
All four no-order checks                  : COMPLETED — ZERO ROWS
Base64 input requirement                  : CONFIRMED
Decoded payload type                     : JSON object / JObject
Specific order structure required         : CONFIRMED
Exact business JSON schema                : NOT CONFIRMED
Business-property guessing                : STOPPED
Metadata call-site discovery              : RESUMED BY USER
Current EventActions fields               : EXHAUSTED — ZERO ROWS
EventActionRevisions property discovery   : COMPLETED
EventActionRevisions.Parameters search    : NEXT
```

## Confirmed Runtime Findings

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ locate expected non-blank order structure
→ business schema validation
→ Customer Order and line processing
```

Completed probes:

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

All four post-probe `dbo.co_mst` checks returned zero rows with no SQL error.

Business-result rules discovered:

```text
- MessageCode = 0 does not establish business success.
- CoResult is returned as a JSON-array string.
- Evaluate business Status independently.
- Failure records may or may not include ErrrorMessage.
```

## Completed Current-Metadata Searches

All searches below succeeded technically and returned zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
```

The current `EventActions` path is exhausted. This does not prove that no standard call site exists.

## Decision History

```text
30 July 2026 — metadata discovery was temporarily stopped for a possible stored-procedure path.
30 July 2026 — user explicitly requested metadata discovery to continue.
```

The stored-procedure option remains documented in `implementation/19-controlled-sp-direct-order-processing.md`, but it is deferred and is not the active next step.

## Confirmed EventActionRevisions Properties

Tenant IDOInfo confirmed the following relevant fields:

```text
ExpandedParameters      : String(4000), read-only
ActionType              : Byte
Description             : String(40)
EventHandlerRowPointer  : GUID
Parameters              : String(3800)
Sequence                : Short Integer
RowPointer              : GUID, read-only
```

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
```

The first revision search field is raw `Parameters`. `ExpandedParameters` remains a later separate fallback.

## Current Small Step

Run this read-only REST v1 request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActionRevisions/adv?props=ActionType,Description,EventHandlerRowPointer,Sequence,Parameters,ExpandedParameters,RowPointer&filter=Parameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, including an empty result.

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines.
- Do not guess Customer Order JSON properties.
- Do not edit revisions, actions, handlers, scripts, events, or metadata.
- Do not search ExpandedParameters or EventHandlerRevisions in the same step.
- Do not implement Process/Reprocess or direct table inserts yet.
```