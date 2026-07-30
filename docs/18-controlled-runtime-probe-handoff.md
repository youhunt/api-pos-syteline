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
Script-name collection discovery                 : COMPLETED — NO USEFUL APP SCRIPT CANDIDATE
Next step                                        : search CollectionDesc for script
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

## Revision Metadata Findings

`EventActionRevisions.ExpandedParameters LIKE '%CreateCoAndLines%'` returned `IllegalFilterException`, `MessageCode = 450`, and `Items = null`.

This was a rejected filter, not a zero-row search.

`EventHandlerRevisions` exposes handler context and child `EventActionRevisions`/`EventActions`, but no direct text property such as `MethodToCall` or `Parameters`.

## Script Collection Discovery

The read-only search:

```text
CollectionName LIKE '%Script%'
```

returned three collections:

```text
BuildApplicationMessagesScript : MGCore/Core temporary application-message script-generation IDO
UTScripts                      : UnitTesting/BaseSyteLine
UTScriptSelections             : UnitTesting/BaseSyteLine
```

No obvious production form-script or global-script metadata collection was identified by name.

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-script-named-metadata-collections.md
```

## Decision History

```text
30 July 2026 — user temporarily approved pivoting to a previous stored-procedure approach.
30 July 2026 — user explicitly instructed the project to continue CreateCoAndLines metadata discovery.
```

The stored-procedure option remains deferred and unimplemented.

## Next Step Only

Search tenant collection descriptions for `script`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionDesc%20LIKE%20%27%25script%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, including an empty result.

Do not load candidate collection rows, invoke `CreateCoAndLines`, edit metadata, guess business-schema properties, or execute SQL in the same step.
