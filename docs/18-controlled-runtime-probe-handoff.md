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
Next step                                        : inspect form collection bindings
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

These searches returned zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
EventActionRevisions.Parameters LIKE '%CreateCoAndLines%'
```

`EventActionRevisions.ExpandedParameters` was rejected with `IllegalFilterException`, not confirmed as zero rows.

`FormsAndObjects` method and parameter metadata was inspected. The visible `Form Control > Utilities` UI was then confirmed to contain only device synchronization actions, so that UI path was stopped without executing any Sync action.

## CustomerOrdersQuickEntry Direction

The user identified `CustomerOrdersQuickEntry` and confirmed that it visibly contains both:

```text
Customer Order header
Customer Order item/detail lines
```

It is now the strongest tenant-specific candidate for discovering either:

```text
SL.SLCos.CreateCoAndLines
```

or an equivalent standard header-plus-line save/event sequence.

No claim is made yet about its actual IDO collections or invoked method.

## Next Step Only

Open `CustomerOrdersQuickEntry` in Design Mode and capture the form collection definitions showing:

```text
- primary collection;
- secondary/subcollection names;
- aliases;
- parent-child relationship, when visible.
```

Do not save, customize, check out, submit, or create an order.

## Evidence

```text
tests/evidence/2026-07-31-user-reconfirms-createcoandlines-path.md
tests/evidence/2026-07-31-customerordersquickentry-selected-as-call-site-candidate.md
```
