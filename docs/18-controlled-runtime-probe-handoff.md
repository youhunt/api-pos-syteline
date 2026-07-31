# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Current Status

```text
Environment                                      : DEV / Infor Cloud tenant
Method                                           : SL.SLCos.CreateCoAndLines
Runtime transport                                : Base64
Decoded payload                                  : JSON object / JObject
Exact business JSON schema                       : NOT CONFIRMED
Controlled probes                                : COMPLETED
Post-probe co_mst checks                         : ZERO ROWS
Direct event/action searches                     : EXHAUSTED / ZERO ROWS
Form Control Utilities                           : DEVICE SYNC ONLY — STOPPED
Primary form call-site candidate                 : CustomerOrdersQuickEntry
Header binding                                   : SLCos / oSLCos — CONFIRMED
Line binding                                     : SLCoitems / oLines subcollection — CONFIRMED
Form Event Handlers search for CreateCoAndLines  : NO MATCH DISPLAYED
Standard save lifecycle events                   : VISIBLE
Next step                                        : expand StdFormSave
Direct-insert stored procedure                   : DEFERRED FALLBACK
```

## Confirmed CustomerOrdersQuickEntry Model

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

The line grid is a subcollection grid with `Reload After Child Save` enabled and no custom load method.

## Visible Standard Events

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

This supports ordinary Mongoose form/object persistence as a serious alternative explanation for the form behavior. It does not yet prove that `CreateCoAndLines` is unused elsewhere.

## Next Step Only

Expand only `StdFormSave` and capture every visible handler row, including:

```text
Sequence
Response
Disabled
Response Parameters
```

Do not run Save, create an order, modify the form, invoke `CreateCoAndLines`, or execute direct SQL.

## Evidence

```text
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
tests/evidence/2026-07-31-customerordersquickentry-createcoandlines-event-search-no-match.md
tests/evidence/2026-07-31-customerordersquickentry-standard-save-events-visible.md
```
