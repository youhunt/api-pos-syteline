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
FormsAndObjects IDOInfo Methods section           : NOT EXPOSED
FormsAndObjects method metadata                  : COMPLETED — 37 METHODS
Next step                                        : compare pseudo-code method parameters
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

No obvious persistent form-definition field is published for `FormName`, `Script`, `EventName`, `MethodToCall`, or `Parameters`.

Do not filter `FormsAndObjects` directly for `CreateCoAndLines`, and do not assume `DerXMLData` or `DerBinaryData` contains form source.

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
FormControlListCustomLoad  : Load drop down lists of forms or objects
FormReferencedObjects      : Load referenced objects based on form
TreeLoadObjects            : Load individual objects for Utilities tree
UtilitiesListNames         : Get names of objects for Utilities drop downs
UtilitiesLoadObjects       : Load objects for utilities form
UtilitiesLoadObjects2      : Load objects for utilities form
UtilitiesGeneratePseudoCode: Generate pseudo code and store output in SQL temp table
UtilitiesGeneratePseudoCode2: Generate pseudo code and store output in SQL temp table
GetUtilitiesOutput         : no tenant description published
```

Possible inferred flow:

```text
UtilitiesListNames
→ UtilitiesLoadObjects / UtilitiesLoadObjects2
→ UtilitiesGeneratePseudoCode / UtilitiesGeneratePseudoCode2
→ GetUtilitiesOutput
```

This flow is not yet confirmed. No method has been invoked.

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
```

## Decision History

```text
30 July 2026 — user temporarily approved a possible previous stored-procedure approach.
30 July 2026 — user explicitly instructed the project to continue CreateCoAndLines metadata discovery.
```

The stored-procedure option remains deferred and unimplemented.

## Next Step Only

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoMethodParameters/adv?props=CollectionName,MethodName,ParameterName,Sequence,DataType,InputFlag,OutputFlag,MessageFlag&filter=CollectionName%20%3D%20%27FormsAndObjects%27%20AND%20MethodName%20LIKE%20%27UtilitiesGeneratePseudoCode%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Do not invoke a `FormsAndObjects` method, generate pseudo code, load a form object, invoke `CreateCoAndLines`, edit metadata, guess business-schema properties, or execute SQL.