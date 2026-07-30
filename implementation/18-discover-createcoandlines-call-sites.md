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
EventHandlerRevisions direct text search          : NOT AVAILABLE
Script metadata discovery                         : NO USEFUL APP SCRIPT CANDIDATE
Form metadata collection discovery                : COMPLETED
Selected form metadata candidate                  : FormsAndObjects
FormsAndObjects properties                        : CONFIRMED
FormsAndObjects IDOInfo Methods section            : NOT EXPOSED
FormsAndObjects IdoMethods rows                   : COMPLETED — 37 METHODS
Pseudo-code parameter comparison                  : COMPLETED
GetUtilitiesOutput parameter discovery            : NEXT
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

Business-result rules:

```text
- MessageCode = 0 does not establish business success.
- CoResult is returned as a JSON-array string.
- Evaluate business Status independently.
- Failure records may or may not include ErrrorMessage.
```

Four controlled malformed/non-business probes were completed. Four post-probe read-only `dbo.co_mst` checks returned zero rows with no SQL error.

## Completed Direct Metadata Searches

The following read-only searches completed successfully and returned zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'
```

`EventActionRevisions.ExpandedParameters` could not be evaluated because the tenant rejected the filter with `IllegalFilterException`, `MessageCode = 450`, and `Items = null`. This is a rejected filter, not a zero-row result.

`EventHandlerRevisions` exposes handler context and child action collections, but no direct call-site text property comparable to `MethodToCall` or `Parameters`.

## Script and Form Metadata Discovery

Searching collection names and descriptions for `Script` did not identify a production form/global-script metadata source.

The broad tenant search for collection names containing `Form` produced many lexical false positives. Relevant tenant-published candidates were:

| CollectionName | CollectionDesc | ServerName | AccessAs |
| --- | --- | --- | --- |
| `FormsAndObjects` | Wrapper for FormControl and FormSync | `MGCore` | `Core` |
| `FormAliases` | NULL | `MGCore` | `Core` |
| `AppForms` | IDO for Widget Forms | `MGCore` | `Core` |
| `DocTypeFormProperties` | NULL | `MGCore` | `Core` |
| `WSFormExtensionHints` | NULL | `MGCore` | `Core` |

`FormsAndObjects` was selected as the strongest tenant-confirmed candidate.

Its IDOInfo response exposes utility-style properties including object selectors, type/scope/configuration fields, action/process controls, XML/binary transfer fields, and output/diagnostic fields. It does not expose an obvious persistent field named `FormName`, `Script`, `EventName`, `MethodToCall`, or `Parameters`.

Therefore:

```text
- do not filter FormsAndObjects directly for CreateCoAndLines;
- do not assume DerXMLData or DerBinaryData contains form source;
- discover its method contracts through IdoMethods and IdoMethodParameters.
```

## FormsAndObjects Method Discovery

The tenant's `idoinfo/FormsAndObjects` response exposes `Properties` but no `Methods` array. Method discovery therefore used `IdoMethods`.

Tenant result:

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
Rows returned  : 37
MethodType 2   : 17
MethodType 3   : 20
TxnFlag 0      : 37
StoredProcName : NULL for all rows
```

Most relevant methods:

```text
FormControlListCustomLoad   : Load drop down lists of forms or objects
FormReferencedObjects       : Load referenced objects based on form
TreeLoadObjects             : Load individual objects for Utilities tree
UtilitiesListNames          : Get names of objects for Utilities drop downs
UtilitiesLoadObjects        : Load objects for utilities form
UtilitiesLoadObjects2       : Load objects for utilities form
UtilitiesGeneratePseudoCode : Generate pseudo code and store output in SQL temp table
UtilitiesGeneratePseudoCode2: Generate pseudo code and store output in SQL temp table
GetUtilitiesOutput          : no tenant description published
```

Possible inferred flow:

```text
UtilitiesListNames
→ UtilitiesLoadObjects / UtilitiesLoadObjects2
→ UtilitiesGeneratePseudoCode / UtilitiesGeneratePseudoCode2
→ GetUtilitiesOutput
```

This flow is not confirmed. No method has been invoked.

## Pseudo-Code Generator Parameter Contracts

Both methods expose 12 `VARIANT` parameters.

Common sequence:

| Sequence | Parameter | Direction |
| ---: | --- | --- |
| 0 | `SessionID` | input |
| 1 | `SourceConfig` | input |
| 2 | `TargetConfig` | input |
| 3 | `Source` | input |
| 4 | `DatabaseName` | input |
| 5 | `Type` | input |
| 6 | `Scope` | input |
| 8 | `ObjectList` | input |
| 9 | `Version` | input |
| 10 | `SegmentCount` | input/output |
| 11 | `CompareIncludeSettings` | input |

Only sequence 7 differs:

```text
UtilitiesGeneratePseudoCode  : RelativePosition
UtilitiesGeneratePseudoCode2 : Options
```

No parameter is marked as a message parameter. The valid values and serialization formats for the `VARIANT` inputs are still unknown.

The method descriptions state that generated pseudo-code is stored in a SQL temporary table. `GetUtilitiesOutput` is therefore the strongest current candidate for retrieving it, but this remains an inference until its parameter contract is inspected.

Evidence:

```text
tests/evidence/2026-07-30-form-named-metadata-collections.md
tests/evidence/2026-07-30-formsandobjects-idoinfo-properties.md
tests/evidence/2026-07-30-formsandobjects-idoinfo-no-methods-section.md
tests/evidence/2026-07-30-formsandobjects-idomethods-list.md
tests/evidence/2026-07-30-formsandobjects-pseudocode-method-parameters.md
```

## Decision History

```text
30 July 2026 — metadata discovery was temporarily stopped for a possible stored-procedure path.
30 July 2026 — user explicitly requested CreateCoAndLines metadata discovery to continue.
```

The stored-procedure option remains documented in `implementation/19-controlled-sp-direct-order-processing.md`, but it is deferred and is not the active path.

## Current Small Step

Read only the parameter metadata for `GetUtilitiesOutput`:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27FormsAndObjects%27%20AND%20MethodName%20%3D%20%27GetUtilitiesOutput%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Do not invoke a `FormsAndObjects` method, generate pseudo-code, create a SQL temporary table, load a form object, invoke `CreateCoAndLines`, edit metadata, guess Customer Order JSON properties, or execute SQL.