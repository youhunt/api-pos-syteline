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
Script-name discovery                            : NO USEFUL APP SCRIPT CANDIDATE
Script-description discovery                     : NO USEFUL APP SCRIPT CANDIDATE
Form metadata discovery                          : COMPLETED
Selected form metadata candidate                 : FormsAndObjects
Next step                                        : FormsAndObjects IDOInfo
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

`EventActionRevisions.ExpandedParameters` could not be evaluated because the tenant rejected the server-side filter with `IllegalFilterException`, `MessageCode = 450`, and `Items = null`. This is not a zero-row result.

`EventHandlerRevisions` exposes handler context and child action collections but no direct call-site text field.

## Script Metadata Discovery

Name search returned only:

```text
BuildApplicationMessagesScript : temporary application-message script generation
UTScripts                      : UnitTesting
UTScriptSelections             : UnitTesting
```

Description search returned:

```text
BuildApplicationMessagesScript : temporary application-message script generation
Deployment                     : deployment scripts/XML for applet deployment
SLInvSequences                 : false positive; "description" contains substring "script"
SLInvSequences_IDS             : same false-positive mechanism
```

No production form/global script metadata source has been identified through the script-name or script-description paths.

## Form Metadata Discovery

The broad tenant search for collection names containing `Form` completed successfully with `MessageCode = 0` and `MoreRowsExists = false`.

Many results were lexical false positives from words such as:

```text
Performance
Formula
Information
Format
ProForma
```

Relevant candidates:

| CollectionName | CollectionDesc | ServerName | AccessAs |
| --- | --- | --- | --- |
| `FormsAndObjects` | Wrapper for FormControl and FormSync | `MGCore` | `Core` |
| `FormAliases` | NULL | `MGCore` | `Core` |
| `AppForms` | IDO for Widget Forms | `MGCore` | `Core` |
| `DocTypeFormProperties` | NULL | `MGCore` | `Core` |
| `WSFormExtensionHints` | NULL | `MGCore` | `Core` |

Selected candidate:

```text
FormsAndObjects
```

It is the strongest tenant-confirmed candidate because its description directly references `FormControl` and `FormSync`. This does not yet prove that it exposes script text or contains `CreateCoAndLines`.

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-script-named-metadata-collections.md
tests/evidence/2026-07-30-script-description-metadata-collections.md
tests/evidence/2026-07-30-form-named-metadata-collections.md
```

## Decision History

```text
30 July 2026 — user temporarily approved pivoting to a previous stored-procedure approach.
30 July 2026 — user explicitly instructed the project to continue CreateCoAndLines metadata discovery.
```

The stored-procedure option remains deferred and unimplemented.

## Next Step Only

Read the property metadata for `FormsAndObjects`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/FormsAndObjects
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Send the complete JSON response, especially `Properties`.

Do not load `FormsAndObjects` rows, inspect another form collection, invoke `CreateCoAndLines`, edit metadata, guess business-schema properties, or execute SQL in the same step.
