# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                                      : DEV
Controlled malformed probes                      : COMPLETED
All four no-order checks                          : COMPLETED — ZERO ROWS
Base64 input requirement                          : CONFIRMED
Decoded payload type                             : JSON object / JObject
Specific order structure required                 : CONFIRMED
Exact business JSON schema                        : NOT CONFIRMED
Business-property guessing                        : STOPPED
Metadata call-site discovery                      : RESUMED BY USER
Current EventActions fields                       : EXHAUSTED — ZERO ROWS
EventActionRevisions.Parameters search            : COMPLETED — ZERO ROWS
EventActionRevisions.ExpandedParameters filter    : FAILED — ILLEGAL FILTER
EventHandlerRevisions property discovery          : NEXT
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

Business-result rules:

```text
- MessageCode = 0 does not establish business success.
- CoResult is returned as a JSON-array string.
- Evaluate business Status independently.
- Failure records may or may not include ErrrorMessage.
```

## Completed Current-Metadata Searches

These searches completed successfully and returned zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'
```

The current `EventActions` path is exhausted. This does not prove that no standard call site exists.

## Decision History

```text
30 July 2026 — metadata discovery was temporarily stopped for a possible stored-procedure path.
30 July 2026 — user explicitly requested metadata discovery to continue.
```

The stored-procedure option remains documented in `implementation/19-controlled-sp-direct-order-processing.md`, but it is deferred and is not the active path.

## Confirmed EventActionRevisions Properties

Tenant IDOInfo confirmed:

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

## Completed Step — Raw EventActionRevisions.Parameters

```text
Filter          : Parameters LIKE '%CreateCoAndLines%'
Message         : Success
MessageCode     : 0
Rows returned   : 0
MoreRowsExists  : false
Conclusion      : no raw revision Parameters reference found
```

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
```

## Failed Step — EventActionRevisions.ExpandedParameters Filter

Request:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActionRevisions/adv?props=ActionType,Description,EventHandlerRowPointer,Sequence,Parameters,ExpandedParameters,RowPointer&filter=ExpandedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Tenant result:

```text
Message        : Error processing LoadCollection request: IllegalFilterException
MessageCode    : 450
Items          : null
Bookmark       : null
MoreRowsExists : false
```

Interpretation:

```text
- The request did not execute a valid search.
- This is not a zero-row result.
- ExpandedParameters cannot be relied on as a server-side filter in this path.
- Do not retry the same filter syntax.
```

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
```

## Current Small Step — Read EventHandlerRevisions Property Metadata

Before filtering handler revisions, inspect the tenant-published property contract:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/EventHandlerRevisions
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, especially `Properties`.

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines.
- Do not guess Customer Order JSON properties.
- Do not edit revisions, actions, handlers, scripts, events, or metadata.
- Do not filter EventHandlerRevisions until its actual property contract is confirmed.
- Do not implement Process/Reprocess or direct table inserts yet.
```
