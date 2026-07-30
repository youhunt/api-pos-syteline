# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                              : DEV
Controlled malformed probes              : COMPLETED
All four no-order checks                  : COMPLETED — ZERO ROWS
Base64 input requirement                  : CONFIRMED
Decoded payload type                     : JSON object / JObject
Specific order structure required         : CONFIRMED
Exact business JSON schema                : NOT CONFIRMED
Business-property guessing                : STOPPED
Metadata call-site discovery              : STOPPED BY USER-APPROVED PIVOT
Further EventAction revision discovery    : CANCELLED
Replacement implementation path           : implementation/19-controlled-sp-direct-order-processing.md
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

Business-result rules discovered:

```text
- MessageCode = 0 does not establish business success.
- CoResult is returned as a JSON-array string.
- Evaluate business Status independently.
- Failure records may or may not include ErrrorMessage.
```

## Completed Metadata Searches

All searches below succeeded technically and returned zero rows:

```text
EventHandlers.MethodToCall LIKE '%CreateCoAndLines%'
EventActions.Parameters LIKE '%CreateCoAndLines%'
EventActions.ExpandedParameters LIKE '%CreateCoAndLines%'
EventActions.SubstitutedParameters LIKE '%CreateCoAndLines%'
```

This did not prove that no standard call site existed. Remaining revision/form/script paths were available, but the user approved stopping this investigation because a previous working integration used a stored procedure with direct inserts into `co_mst` and `coitem_mst`.

## Decision Closure

```text
Decision date          : 30 July 2026
User approval          : CONFIRMED
CreateCoAndLines path  : CLOSED
Next path              : controlled stored procedure review and adaptation
SQL implemented        : NO
SQL executed           : NO
```

Continue with:

```text
implementation/19-controlled-sp-direct-order-processing.md
```

The previous working stored procedure must be reviewed before a replacement or adaptation is written.
