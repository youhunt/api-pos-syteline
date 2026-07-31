# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                                      : DEV / Infor Cloud tenant
Active Customer Order path                       : SL.SLCos.CreateCoAndLines
Direct-insert stored procedure                   : DEFERRED FALLBACK
Base64 input requirement                         : CONFIRMED
Decoded payload type                             : JSON object / JObject
Exact business JSON schema                       : NOT CONFIRMED
Controlled malformed probes                      : COMPLETED
All post-probe co_mst checks                     : ZERO ROWS
Direct event/action text searches                : EXHAUSTED / ZERO ROWS
Form Control Utilities tab                       : DEVICE SYNC ONLY — STOPPED
Primary form call-site candidate                 : CustomerOrdersQuickEntry
CustomerOrdersQuickEntry header binding          : SLCos / oSLCos — CONFIRMED
CustomerOrdersQuickEntry line binding            : SLCoitems / oLines subcollection — CONFIRMED
CreateCoAndLines form reference                  : NOT YET CONFIRMED
Next step                                        : inspect form event handlers/scripts
```

## Confirmed Runtime Contract

```text
CoAndLineInfoJson
→ Base64 decode
→ JSON object / JObject parse
→ locate expected nonblank order structure
→ business validation
→ Customer Order and line processing
```

Business-result rules:

```text
- MessageCode = 0 is framework success only.
- CoResult is an input/output message parameter.
- CoResult is returned as a JSON-array string.
- Business Status must be evaluated independently.
- ErrrorMessage may be present with three r characters.
```

## Controlled Probe History

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

Four read-only `dbo.co_mst` checks after the probes returned zero rows and no SQL error.

## Completed Direct Metadata Searches

These read-only searches completed successfully and returned zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'
```

`EventActionRevisions.ExpandedParameters` could not be filtered because the tenant returned `IllegalFilterException`, `MessageCode = 450`, and `Items = null`. This was a rejected filter, not a zero-row result.

`EventHandlerRevisions` exposes handler context and child action collections but no direct call-site text property.

## FormsAndObjects Findings

`FormsAndObjects` was inspected because it is described as `Wrapper for FormControl and FormSync`. Its property contract is utility-oriented and does not expose obvious persistent properties named `FormName`, `Script`, `EventName`, `MethodToCall`, or `Parameters`.

`IdoMethods` confirmed 37 methods, including pseudo-code utilities. Their method and parameter contracts were documented, but the visible `Form Control > Utilities` screen contained only device-type synchronization actions. That UI path was stopped without executing Sync.

## CustomerOrdersQuickEntry Findings

The user identified `CustomerOrdersQuickEntry` as a standard tenant form containing Customer Order header and item/detail lines.

Design Mode evidence confirms:

```text
Primary Collection      : SLCos
Primary Collection Name : oSLCos
Custom Load Method      : blank

Line Binding Type       : SubCollection Grid
Parent Collection       : primary collection
Subcollection Property  : SLCoitems
Line Collection Name    : oLines
Custom Load Method      : blank
Reload After Child Save : enabled
Update Locking          : Row
```

A top-level `Secondary Collection 2: SLAppsParms` is also present, but its alias and role were not captured in this step.

Confirmed relationship:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

This proves the form uses the standard header-plus-line data model required by SMK069. It does not prove that it calls `CreateCoAndLines`. Because standard Save is enabled for the subcollection and no custom load method is configured, the form may use normal parent/child persistence or additional form event/script logic.

## Active Discovery Plan

```text
1. Search CustomerOrdersQuickEntry form events/scripts for CreateCoAndLines.
2. If found, capture the event, script, parameter construction, and Base64 encoding.
3. If not found, inspect New, Save, and Quick Order Verification event sequences.
4. Determine whether the form uses CreateCoAndLines or ordinary SLCos/SLCoitems collection save.
5. Build one minimal valid DEV payload only after the exact contract is confirmed.
6. Invoke CreateCoAndLines once under controlled conditions.
7. Verify both co_mst and coitem_mst.
8. Reuse the verified contract for SMK069 Process/Reprocess.
```

## Current Small Step

Open the form-level Event Handlers/Scripts for `CustomerOrdersQuickEntry` and search for:

```text
CreateCoAndLines
```

Capture the matching handler/script and its actions or code. If the search returns no match, capture that result only; do not inspect another event in the same step.

Do not save, customize, check out, submit, or create an order.

## Evidence

```text
tests/evidence/2026-07-30-eventactionrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-eventactionrevisions-parameters-createcoandlines-no-match.md
tests/evidence/2026-07-30-eventactionrevisions-expandedparameters-illegal-filter.md
tests/evidence/2026-07-30-eventhandlerrevisions-idoinfo-properties.md
tests/evidence/2026-07-30-formsandobjects-idomethods-list.md
tests/evidence/2026-07-30-formsandobjects-pseudocode-method-parameters.md
tests/evidence/2026-07-31-formsandobjects-getutilitiesoutput-parameters.md
tests/evidence/2026-07-31-user-reconfirms-createcoandlines-path.md
tests/evidence/2026-07-31-customerordersquickentry-selected-as-call-site-candidate.md
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
```

## Safety Boundary

```text
- No CreateCoAndLines invocation yet.
- No Customer Order creation.
- No form checkout or metadata modification.
- No FormSync/device synchronization.
- No direct insert into co_mst or coitem_mst.
```