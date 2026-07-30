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
Script-description collection discovery           : COMPLETED — NO USEFUL APP SCRIPT CANDIDATE
Form metadata collection discovery                : COMPLETED
Selected form metadata candidate                  : FormsAndObjects
FormsAndObjects property discovery                : NEXT
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

## Revision Metadata Findings

`EventActionRevisions` publishes raw `Parameters` plus derived/read-only `ExpandedParameters`.

The raw search returned zero rows. Filtering the derived field returned:

```text
Message        : Error processing LoadCollection request: IllegalFilterException
MessageCode    : 450
Items          : null
Bookmark       : null
MoreRowsExists : false
```

This was a rejected filter, not a zero-row result. Do not retry the same filter syntax.

`EventHandlerRevisions` exposes handler context and child `EventActionRevisions`/`EventActions`, but no direct call-site text property comparable to `MethodToCall` or `Parameters`.

Evidence:

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
```

## Script Metadata Discovery

### CollectionName contains Script

The tenant returned:

```text
BuildApplicationMessagesScript : temporary application-message script-generation IDO
UTScripts                      : UnitTesting collection
UTScriptSelections             : UnitTesting selection collection
```

No obvious production form/global script metadata collection was identified.

### CollectionDesc contains script

The tenant returned:

```text
BuildApplicationMessagesScript : temporary application-message script-generation IDO
Deployment                     : deployment script/XML processing
SLInvSequences                 : false positive from substring "script" inside "description"
SLInvSequences_IDS             : same false-positive mechanism
```

`Deployment` concerns applet deployment scripts/XML, not application form/global script metadata. The two invoice-sequence rows are lexical false positives because the word `description` contains the substring `script`.

Evidence:

```text
tests/evidence/2026-07-30-script-named-metadata-collections.md
tests/evidence/2026-07-30-script-description-metadata-collections.md
```

## Form Metadata Discovery

The tenant-wide search:

```text
CollectionName LIKE '%Form%'
```

completed successfully with:

```text
Message        : Success
MessageCode    : 0
MoreRowsExists : false
```

The broad substring produced many unrelated results because `Form` also occurs inside:

```text
Performance
Formula
Information
Format
ProForma
```

The relevant tenant-published candidates are:

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

Selection reason:

```text
CollectionDesc = Wrapper for FormControl and FormSync
ServerName     = MGCore
AccessAs       = Core
```

This is the strongest tenant-confirmed candidate for classic form/object metadata. `AppForms` is explicitly widget-oriented, while `FormAliases` appears limited to aliases.

No claim is made yet that `FormsAndObjects` contains script text or a `CreateCoAndLines` reference. Its actual property contract must be read first.

Evidence:

```text
tests/evidence/2026-07-30-form-named-metadata-collections.md
```

## Decision History

```text
30 July 2026 — metadata discovery was temporarily stopped for a possible stored-procedure path.
30 July 2026 — user explicitly requested metadata discovery to continue.
```

The stored-procedure option remains documented in `implementation/19-controlled-sp-direct-order-processing.md`, but it is deferred and is not the active path.

## Current Small Step — Read FormsAndObjects Property Metadata

Read the tenant-published property contract before loading or filtering form rows:

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/idoinfo/FormsAndObjects
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response, especially `Properties`.

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines.
- Do not guess Customer Order JSON properties.
- Do not edit revisions, actions, handlers, scripts, forms, events, or metadata.
- Do not load FormsAndObjects rows until its property contract is confirmed.
- Do not implement Process/Reprocess or direct table inserts yet.
```
