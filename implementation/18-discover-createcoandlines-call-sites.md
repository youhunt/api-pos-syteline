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
Direct event/action metadata searches            : EXHAUSTED / ZERO ROWS
Form Control Utilities tab                       : DEVICE SYNC ONLY — STOPPED
Primary form call-site candidate                 : CustomerOrdersQuickEntry
Header binding                                   : SLCos / oSLCos — CONFIRMED
Line binding                                     : SLCoitems / oLines subcollection — CONFIRMED
CreateCoAndLines form-handler search              : COMPLETED — NO MATCH DISPLAYED
Standard form/object save lifecycle              : VISIBLE
Next step                                        : expand StdFormSave
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

## Controlled Probe and Metadata History

Four malformed/non-business probes were completed. Four read-only `dbo.co_mst` checks returned zero rows and no SQL error.

The following direct metadata searches completed with zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'
```

`EventActionRevisions.ExpandedParameters` was rejected with `IllegalFilterException`; it is not a zero-row result.

`FormsAndObjects` method metadata and pseudo-code utility contracts were inspected. The visible `Form Control > Utilities` UI contained only device synchronization actions, so that path was stopped without executing Sync.

## CustomerOrdersQuickEntry Findings

Design Mode confirms:

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

Confirmed relationship:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

A top-level `Secondary Collection 2: SLAppsParms` also exists; its role remains uninspected.

The form-level Event Handlers search for `CreateCoAndLines` displayed no matching row. The visible handler list then showed these standard lifecycle events:

```text
StdFormSave
StdFormSaveCompleted
StdFormSaveCompletedLine
StdObjectNew
StdObjectSave
StdObjectSaveCompleted
StdObjectSaveCurrentCompleted
StdObjectSaveLine
```

This supports the possibility that the form uses ordinary standard parent/child collection persistence rather than a form handler explicitly named `CreateCoAndLines`. The responses attached to these events are not yet confirmed.

## Active Discovery Plan

```text
1. Expand StdFormSave and capture its handler responses.
2. Follow only the exact next event or method referenced by those responses.
3. Determine whether the chain reaches StdObjectSave/StdObjectSaveLine, an IDO method, or script logic.
4. Confirm whether CustomerOrdersQuickEntry uses CreateCoAndLines or ordinary SLCos/SLCoitems Save.
5. Build one minimal valid DEV payload only after the exact contract is confirmed.
6. Invoke CreateCoAndLines once under controlled conditions when justified.
7. Verify both co_mst and coitem_mst.
8. Reuse the verified mechanism for SMK069 Process/Reprocess.
```

## Current Small Step

In Design Mode, expand only:

```text
StdFormSave
```

Capture all visible child handler rows and columns:

```text
Sequence
Response
Disabled
Response Parameters
```

Do not execute Save at runtime, modify the form, create an order, invoke `CreateCoAndLines`, or execute direct SQL.

## Evidence

```text
tests/evidence/2026-07-31-customerordersquickentry-selected-as-call-site-candidate.md
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
tests/evidence/2026-07-31-customerordersquickentry-createcoandlines-event-search-no-match.md
tests/evidence/2026-07-31-customerordersquickentry-standard-save-events-visible.md
```
