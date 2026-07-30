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
Script metadata discovery                         : NO USEFUL APP SCRIPT CANDIDATE
Form metadata collection discovery                : COMPLETED
Selected form metadata candidate                  : FormsAndObjects
FormsAndObjects property discovery                : COMPLETED
Direct FormsAndObjects text search                : NOT AUTHORIZED
FormsAndObjects method discovery                  : NEXT
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

`EventActionRevisions.ExpandedParameters` could not be evaluated because the tenant rejected the filter with:

```text
MessageCode : 450
Exception   : IllegalFilterException
Items       : null
```

This is a rejected filter, not a zero-row result.

`EventHandlerRevisions` exposes handler context and child `EventActionRevisions`/`EventActions`, but no direct call-site text property comparable to `MethodToCall` or `Parameters`.

## Script Metadata Discovery

Searching collection names and descriptions for `Script` did not identify a production form/global-script metadata source.

Confirmed non-candidates:

```text
BuildApplicationMessagesScript : temporary application-message script generation
UTScripts                      : UnitTesting
UTScriptSelections             : UnitTesting
Deployment                     : applet deployment script/XML processing
SLInvSequences                 : lexical false positive from "description"
SLInvSequences_IDS             : same false-positive mechanism
```

## Form Metadata Discovery

The broad tenant search for `CollectionName LIKE '%Form%'` completed successfully. Many results were lexical false positives from words such as `Performance`, `Formula`, `Information`, `Format`, and `ProForma`.

Relevant tenant-published candidates:

| CollectionName | CollectionDesc | ServerName | AccessAs |
| --- | --- | --- | --- |
| `FormsAndObjects` | Wrapper for FormControl and FormSync | `MGCore` | `Core` |
| `FormAliases` | NULL | `MGCore` | `Core` |
| `AppForms` | IDO for Widget Forms | `MGCore` | `Core` |
| `DocTypeFormProperties` | NULL | `MGCore` | `Core` |
| `WSFormExtensionHints` | NULL | `MGCore` | `Core` |

`FormsAndObjects` was selected as the strongest tenant-confirmed candidate because its description directly references `FormControl` and `FormSync`.

## FormsAndObjects Property Contract

Tenant IDOInfo confirms a wrapper/utility-style contract including:

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

The collection does **not** expose an obvious persistent form-definition property such as:

```text
FormName
Script
EventName
MethodToCall
Parameters
```

Therefore:

```text
- do not filter FormsAndObjects directly for CreateCoAndLines;
- do not assume DerXMLData or DerBinaryData contains form source;
- inspect tenant-published FormsAndObjects methods before loading or invoking anything.
```

Evidence:

```text
tests/evidence/2026-07-30-form-named-metadata-collections.md
tests/evidence/2026-07-30-formsandobjects-idoinfo-properties.md
```

## Decision History

```text
30 July 2026 — metadata discovery was temporarily stopped for a possible stored-procedure path.
30 July 2026 — user explicitly requested CreateCoAndLines metadata discovery to continue.
```

The stored-procedure option remains documented in `implementation/19-controlled-sp-direct-order-processing.md`, but it is deferred and is not the active path.

## Current Small Step

Read only the tenant-published method list/metadata for `FormsAndObjects`. The goal is to identify a read/export/get-object method that can retrieve form/object definitions without invoking it.

Do not load form rows, invoke any `FormsAndObjects` method, invoke `CreateCoAndLines`, guess Customer Order JSON properties, edit metadata, or execute SQL.
