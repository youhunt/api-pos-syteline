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
EventHandlerRevisions direct text search         : NOT AVAILABLE
Script metadata discovery                        : NO USEFUL APP SCRIPT CANDIDATE
Form metadata discovery                          : COMPLETED
Selected form candidate                          : FormsAndObjects
FormsAndObjects properties                       : CONFIRMED
Next step                                        : FormsAndObjects method metadata/list
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

Four controlled malformed/non-business probes and four read-only `dbo.co_mst` checks were completed. Every check returned zero rows with no SQL error.

## Completed Metadata Searches

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'                   : zero rows
EventActions.Parameters LIKE '%CreateCoAndLines%'                       : zero rows
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'               : zero rows
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'            : zero rows
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'                : zero rows
```

The `EventActionRevisions.ExpandedParameters` filter was rejected with `IllegalFilterException`, `MessageCode = 450`, and `Items = null`; it is not a zero-row result.

`EventHandlerRevisions` exposes no direct call-site text property.

## Script and Form Discovery

Script-name and script-description searches did not identify a production form/global-script metadata source.

The broad form-name discovery identified these relevant candidates:

```text
FormsAndObjects        : Wrapper for FormControl and FormSync — MGCore/Core
FormAliases            : MGCore/Core
AppForms               : IDO for Widget Forms — MGCore/Core
DocTypeFormProperties  : MGCore/Core
WSFormExtensionHints   : MGCore/Core
```

`FormsAndObjects` was selected as the strongest candidate.

## FormsAndObjects Property Contract

The tenant publishes utility-style properties including:

```text
DerObjectName
DerObjectType
DerObjectTypeStr
DerRefObjName
DerRefObjType
DerSecondaryObjectName
DerTertiaryObjectName
DerScopeNameStr
DerScopeType
DerScopeTypeStr
DerCurrentConfiguration
DerSourceConfiguration
DerTargetConfiguration
DerAction
DerProcessInformation
DerXMLData
DerBinaryData
Upload
Download
DerOutputText
DerCommandLinks
DerExplanation
DerInstruction
LicenseDocument
RowPointer
```

No obvious persistent form-definition field is published for:

```text
FormName
Script
EventName
MethodToCall
Parameters
```

Do not filter `FormsAndObjects` directly for `CreateCoAndLines`, and do not assume `DerXMLData` or `DerBinaryData` contains form source.

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-script-named-metadata-collections.md
tests/evidence/2026-07-30-script-description-metadata-collections.md
tests/evidence/2026-07-30-form-named-metadata-collections.md
tests/evidence/2026-07-30-formsandobjects-idoinfo-properties.md
```

## Decision History

```text
30 July 2026 — user temporarily approved a possible previous stored-procedure approach.
30 July 2026 — user explicitly instructed the project to continue CreateCoAndLines metadata discovery.
```

The stored-procedure option remains deferred and unimplemented.

## Next Step Only

Obtain the tenant-published method list/metadata for `FormsAndObjects`. Identify method names and classifications only.

Do not invoke a `FormsAndObjects` method, load a form object, invoke `CreateCoAndLines`, edit metadata, guess business-schema properties, or execute SQL.
