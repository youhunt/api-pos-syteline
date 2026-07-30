# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Current Status

```text
Environment                                      : DEV
Method                                           : SL.SLCos.CreateCoAndLines
Controlled probes                                : COMPLETED
Post-probe co_mst checks                         : COMPLETED — ZERO ROWS
Runtime transport                                : Base64
Decoded payload                                  : JSON object / JObject
Exact business JSON schema                       : NOT CONFIRMED
Metadata call-site discovery                     : RESUMED
Current EventActions searches                    : COMPLETED — ZERO ROWS
EventActionRevisions IDOInfo                     : CONFIRMED
EventActionRevisions.Parameters search           : COMPLETED — ZERO ROWS
Next search                                      : EventActionRevisions.ExpandedParameters
```

## Confirmed Runtime Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ locate expected non-blank order structure
→ business schema validation
→ Customer Order and line processing
```

Business result handling:

```text
- MessageCode = 0 is framework success only.
- Parse CoResult as a JSON-array string.
- Evaluate Status for business success/failure.
- ErrrorMessage is optional and misspelled with three r characters when present.
```

## Completed Probes

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

All four read-only `dbo.co_mst` checks returned zero rows and no SQL error.

## Completed Metadata Searches

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'                   : zero rows
EventActions.Parameters LIKE '%CreateCoAndLines%'                       : zero rows
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'               : zero rows
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'            : zero rows
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'                : zero rows
```

## Decision History

```text
30 July 2026 — user temporarily approved pivoting to a previous stored-procedure approach.
30 July 2026 — user explicitly instructed the project to continue CreateCoAndLines metadata discovery.
```

The stored-procedure option is deferred, not implemented, and remains documented only as an alternative.

## EventActionRevisions Property Contract

Relevant tenant-published fields:

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
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
```

## Next Step Only

Run:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/EventActionRevisions/adv?props=ActionType,Description,EventHandlerRowPointer,Sequence,Parameters,ExpandedParameters,RowPointer&filter=ExpandedParameters%20LIKE%20%27%25CreateCoAndLines%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, including an empty result.

Do not inspect `EventHandlerRevisions`, invoke `CreateCoAndLines`, guess business-schema properties, edit metadata, or execute SQL in the same step.
