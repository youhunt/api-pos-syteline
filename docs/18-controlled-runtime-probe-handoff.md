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
StdFormSave responses                            : CONFIRMED
Strongest source candidate                       : SMK_Save()
Next step                                        : open SMK_Save() source
Direct-insert stored procedure                   : DEFERRED FALLBACK
```

## Confirmed CustomerOrdersQuickEntry Model

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

The line grid is a subcollection grid with `Reload After Child Save` enabled and no custom load method.

## StdFormSave Responses

```text
0 Generate event      LineSetValueForPricingEngine(COLID(object.SLCoitems))
1 Run Script          BdcDeleteVar(COLINE) COLID(object.SLCoitems)
2 Method Call         MGCore.DefineVariables.DefineVariableSp(...) — UI truncated
3 Form Script Method  SMK_Save()
4 Form Script Method  SMK025_UpdateReqDateLineIfEmpty()
```

All five visible responses are enabled (`Disabled = false`).

This confirms custom form logic in the save chain. It does not yet reveal whether `SMK_Save()` calls `CreateCoAndLines`, builds Base64 JSON, or uses another save mechanism.

## Next Step Only

Open the complete source body for:

```text
SMK_Save()
```

Do not edit, compile, save, run the form, create an order, invoke `CreateCoAndLines`, or execute direct SQL.

## Evidence

```text
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
tests/evidence/2026-07-31-customerordersquickentry-createcoandlines-event-search-no-match.md
tests/evidence/2026-07-31-customerordersquickentry-standard-save-events-visible.md
tests/evidence/2026-07-31-customerordersquickentry-stdformsave-responses.md
```
