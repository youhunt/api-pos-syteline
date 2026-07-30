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
EventHandlerRevisions property discovery          : COMPLETED
Direct handler-revision text search               : NOT AVAILABLE
Script-name collection discovery                  : COMPLETED — NO USEFUL APP SCRIPT CANDIDATE
Script-description collection discovery           : NEXT
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

## Completed Direct Metadata Searches

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

## EventActionRevisions Limitation

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

The raw `Parameters` search returned zero rows.

The `ExpandedParameters` filter returned:

```text
Message        : Error processing LoadCollection request: IllegalFilterException
MessageCode    : 450
Items          : null
Bookmark       : null
MoreRowsExists : false
```

This was a rejected filter, not a zero-row result. Do not retry the same filter syntax.

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
```

## EventHandlerRevisions Conclusion

`EventHandlerRevisions` publishes handler context and child collections `EventActionRevisions` and `EventActions`, but no direct call-site text property comparable to `MethodToCall` or `Parameters`.

A direct `CreateCoAndLines` filter on `EventHandlerRevisions` is therefore not supported by the tenant-published property contract.

Evidence:

```text
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
```

## Completed Step — Discover Collections Named Script

Read-only tenant discovery returned:

| CollectionName | Description | ServerName | AccessAs |
| --- | --- | --- | --- |
| `BuildApplicationMessagesScript` | Temp IDO that will hold the Derived Binary Value for the script generation | `MGCore` | `Core` |
| `UTScripts` | NULL | `UnitTesting` | `BaseSyteLine` |
| `UTScriptSelections` | NULL | `UnitTesting` | `BaseSyteLine` |

Confirmed interpretation:

```text
BuildApplicationMessagesScript : temporary application-message script-generation IDO
UTScripts                      : unit-testing collection
UTScriptSelections             : unit-testing selection collection
```

No obvious production form-script or global-script metadata collection was found by `CollectionName LIKE '%Script%'`.

Evidence:

```text
tests/evidence/2026-07-30-script-named-metadata-collections.md
```

## Current Small Step — Search Collection Descriptions

A relevant metadata collection may not contain `Script` in its name. Search the published description instead:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionDesc%20LIKE%20%27%25script%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, including an empty result.

## Interpretation Rules

```text
- A returned collection is only a candidate metadata source.
- Do not infer its property contract from its name, caption, or description.
- Do not load rows from a candidate collection in the same step.
- Do not search form metadata separately in the same step.
```

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines.
- Do not guess Customer Order JSON properties.
- Do not edit revisions, actions, handlers, scripts, events, or metadata.
- Do not implement Process/Reprocess or direct table inserts yet.
```
