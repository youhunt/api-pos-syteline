# 18 — Controlled CreateCoAndLines Runtime Probe Handoff

## Final Status of This Path

```text
Environment                        : DEV
Method                             : SL.SLCos.CreateCoAndLines
Controlled probes                  : COMPLETED
Post-probe co_mst checks           : COMPLETED — ZERO ROWS
Runtime transport                  : Base64
Decoded payload                    : JSON object / JObject
Exact business JSON schema         : NOT CONFIRMED
Metadata call-site discovery       : STOPPED
Further revision discovery         : CANCELLED
Reason                             : user-approved pivot to prior SP approach
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

## Completed Probes

```text
Probe 1 : raw {                         → invalid Base64
Probe 2 : ew==                          → decoded { → JObject parser failure
Probe 3 : e30=                          → decoded {} → blank order input
Probe 4 : eyJwcm9iZSI6dHJ1ZX0=         → decoded {"probe":true} → blank order input
```

All four read-only `dbo.co_mst` checks returned zero rows and no SQL error.

## Completed Metadata Searches

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'             : zero rows
EventActions.Parameters LIKE '%CreateCoAndLines%'                 : zero rows
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'         : zero rows
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'      : zero rows
```

## User-Approved Pivot

On 30 July 2026, the user confirmed a previous successful integration used a stored procedure with direct inserts into:

```text
dbo.co_mst
dbo.coitem_mst
```

The project therefore stops further reverse-engineering of `CreateCoAndLines` and moves to:

```text
implementation/19-controlled-sp-direct-order-processing.md
```

## Next Step Only

Obtain the previous working stored procedure and review it before drafting or executing any SQL.

Required review areas:

```text
- input parameters
- order number generation
- required header and line columns
- defaults, site, warehouse, currency, tax, and dates
- customer and item validation
- transaction/rollback behavior
- duplicate and reprocess protection
- staging status and error updates
```

No direct-insert procedure is considered approved merely because the earlier version worked. It must first be adapted to the current tenant and current `SMK069` staging design.
