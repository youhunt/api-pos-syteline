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
Next step                                        : inspect Quick Order Verification component event
Direct-insert stored procedure                   : DEFERRED FALLBACK
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

Business result handling:

```text
- MessageCode = 0 is framework success only.
- CoResult is an input/output message parameter.
- CoResult is returned as a JSON-array string.
- Evaluate business Status independently.
- ErrrorMessage may be returned with three r characters.
```

## Completed Probe and Metadata Work

Four malformed/non-business probes were completed. Four read-only checks of `dbo.co_mst` returned zero rows and no SQL error.

Direct event/action metadata searches for `CreateCoAndLines` returned zero rows. `EventActionRevisions.ExpandedParameters` was rejected with `IllegalFilterException`, not confirmed as zero rows.

The visible `Form Control > Utilities` UI was confirmed to contain only device synchronization actions, so that path was stopped without executing Sync.

## CustomerOrdersQuickEntry Evidence

Design Mode confirms:

```text
Primary collection      : SLCos
Primary alias/name      : oSLCos
Header custom load      : blank

Detail binding type     : SubCollection Grid
Parent collection       : primary collection
Subcollection property  : SLCoitems
Detail alias/name       : oLines
Detail custom load      : blank
Reload after child save : enabled
Update locking          : Row
```

A top-level `Secondary Collection 2: SLAppsParms` is visible, but its role was not captured.

Confirmed relationship:

```text
oSLCos / SLCos
└── oLines / SLCoitems
```

This confirms the standard Customer Order header/detail model. It does not establish that the form calls `CreateCoAndLines`; standard parent-child Save may be used instead.

## Event Search Result

The form-level `Event Handlers` tab was filtered with:

```text
CreateCoAndLines
```

No matching handler row was displayed. This does not rule out component events, scripts, inherited logic, or ordinary collection Save.

## Next Step Only

Select the visible `Quick Order Verification` button in Design Mode and capture its event-generation property, such as `Event To Generate`, `Event`, or the tenant-equivalent field.

Do not click the button at runtime, save, customize, check out, submit, or create an order.

## Evidence

```text
tests/evidence/2026-07-31-user-reconfirms-createcoandlines-path.md
tests/evidence/2026-07-31-customerordersquickentry-selected-as-call-site-candidate.md
tests/evidence/2026-07-31-customerordersquickentry-collection-bindings.md
tests/evidence/2026-07-31-customerordersquickentry-createcoandlines-event-search-no-match.md
```
