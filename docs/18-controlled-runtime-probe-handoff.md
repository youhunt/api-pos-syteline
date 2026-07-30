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
EventActionRevisions.Parameters search           : COMPLETED — ZERO ROWS
EventActionRevisions.ExpandedParameters filter   : FAILED — ILLEGAL FILTER
EventHandlerRevisions IDOInfo                    : CONFIRMED
Direct handler-revision text search              : NOT AVAILABLE
Next step                                        : discover Script metadata collections
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

## EventActionRevisions Contract and Filter Limitation

```text
ExpandedParameters      : String(4000), read-only
ActionType              : Byte
Description             : String(40)
EventHandlerRowPointer  : GUID
Parameters              : String(3800)
Sequence                : Short Integer
RowPointer              : GUID, read-only
```

The filter:

```text
EventActionRevisions.ExpandedParameters LIKE '%CreateCoAndLines%'
```

returned:

```text
Message        : Error processing LoadCollection request: IllegalFilterException
MessageCode    : 450
Items          : null
Bookmark       : null
MoreRowsExists : false
```

This is not a zero-row search. The filter was rejected before a result set was produced.

## EventHandlerRevisions Contract

Relevant tenant-published properties:

```text
EventActionRevisions          : CONTAINS
EventActions                  : CONTAINS
AccessAs                      : String(50)
AppliesToInitiators           : String(255)
AppliesToObjects              : String(255)
AppliesToSites                : String(255)
Description                   : String(40)
EventName                     : String(50), read-only
EventRevision                 : Long Integer, read-only
EventRevisionRowPointer       : GUID, read-only
InitialActionSequence         : Short Integer, read-only
Sequence                      : Short Integer
Synchronous                   : Byte
Transactional                 : Byte
RowPointer                    : GUID, read-only
```

No direct call-site text property such as `MethodToCall` or `Parameters` is exposed. The child action collections are the call-bearing path and have already been investigated as far as the tenant permits through direct filtering.

Evidence:

```text
tests/evidence/2026-07-30-event-handler-metadata-collections.md
tests/evidence/2026-07-30-eventhandlers-idoinfo-properties.md
tests/evidence/2026-07-30-eventhandlers-methodtocall-createcoandlines-no-match.md
tests/evidence/2026-07-30-event-action-metadata-collections.md
tests/evidence/2026-07-30-eventactions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactions-expandedparameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactions-substitutedparameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
```

## Decision History

```text
30 July 2026 — user temporarily approved pivoting to a previous stored-procedure approach.
30 July 2026 — user explicitly instructed the project to continue CreateCoAndLines metadata discovery.
```

The stored-procedure option remains deferred and unimplemented.

## Next Step Only

Discover actual tenant metadata collections whose names contain `Script`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25Script%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, including an empty result.

Do not load script rows, search form metadata, invoke `CreateCoAndLines`, edit metadata, guess business-schema properties, or execute SQL in the same step.
