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
EventActionRevisions.Parameters search            : COMPLETED — ZERO ROWS
EventActionRevisions.ExpandedParameters filter   : FAILED — ILLEGAL FILTER
EventHandlerRevisions direct text search         : NOT AVAILABLE
Script metadata discovery                        : NO USEFUL APP SCRIPT CANDIDATE
Form metadata discovery                          : COMPLETED
Selected form candidate                          : FormsAndObjects
FormsAndObjects properties                       : CONFIRMED
FormsAndObjects IDOInfo Methods section          : NOT EXPOSED
FormsAndObjects method metadata                  : COMPLETED — 37 METHODS
Pseudo-code parameter comparison                 : COMPLETED
Next step                                        : GetUtilitiesOutput parameter metadata
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

Business-result handling:

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

Relevant form-oriented candidates were:

```text
FormsAndObjects        : Wrapper for FormControl and FormSync — MGCore/Core
FormAliases            : MGCore/Core
AppForms               : IDO for Widget Forms — MGCore/Core
DocTypeFormProperties  : MGCore/Core
WSFormExtensionHints   : MGCore/Core
```

`FormsAndObjects` was selected as the strongest candidate.

Its published properties describe a utility/wrapper contract. No obvious persistent property is exposed for `FormName`, `Script`, `EventName`, `MethodToCall`, or `Parameters`.

## FormsAndObjects Method Discovery

The tenant's IDOInfo response exposes `Properties` but no `Methods` array. `IdoMethods` was therefore used.

```text
Rows returned  : 37
MethodType 2   : 17
MethodType 3   : 20
TxnFlag 0      : 37
StoredProcName : NULL for all rows
```

Most relevant methods:

```text
UtilitiesListNames
UtilitiesLoadObjects
UtilitiesLoadObjects2
UtilitiesGeneratePseudoCode
UtilitiesGeneratePseudoCode2
GetUtilitiesOutput
```

Possible inferred flow:

```text
list names
→ load objects
→ generate pseudo-code into SQL temporary table
→ retrieve output
```

This flow is not confirmed. No method has been invoked.

## Pseudo-Code Method Parameters

Both generators expose 12 `VARIANT` parameters.

Common parameters:

```text
0  SessionID                 input
1  SourceConfig              input
2  TargetConfig              input
3  Source                    input
4  DatabaseName              input
5  Type                      input
6  Scope                     input
8  ObjectList                input
9  Version                   input
10 SegmentCount              input/output
11 CompareIncludeSettings    input
```

Sequence 7 differs:

```text
UtilitiesGeneratePseudoCode  : RelativePosition
UtilitiesGeneratePseudoCode2 : Options
```

No parameter is marked as a message parameter. Valid values and serialization formats remain unknown.

`GetUtilitiesOutput` is the strongest current candidate for retrieving generated pseudo-code because both generator descriptions say output is stored in a SQL temporary table. This is still an inference.

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
tests/evidence/2026-07-30-formsandobjects-idoinfo-no-methods-section.md
tests/evidence/2026-07-30-formsandobjects-idomethods-list.md
tests/evidence/2026-07-30-formsandobjects-pseudocode-method-parameters.md
```

## Decision History

```text
30 July 2026 — user temporarily approved a possible previous stored-procedure approach.
30 July 2026 — user explicitly instructed the project to continue CreateCoAndLines metadata discovery.
```

The stored-procedure option remains deferred and unimplemented.

## Next Step Only

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27FormsAndObjects%27%20AND%20MethodName%20%3D%20%27GetUtilitiesOutput%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Do not invoke a `FormsAndObjects` method, generate pseudo-code, create a SQL temporary table, load a form object, invoke `CreateCoAndLines`, edit metadata, guess Customer Order JSON properties, or execute SQL.