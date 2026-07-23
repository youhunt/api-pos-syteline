# IDO-001 — First Inbound IDO Smoke Test

## Status

PASS

## Evidence Date

2026-07-23

## Tested Object

```text
IDO Project : ue_SMKRSCPos
IDO Name    : ue_SMKRSCPosInbounds
```

## Evidence

User-provided screenshot from IDO Data Viewer shows:

- `ue_SMKRSCPosInbounds` is selectable;
- generated properties are recognized, including `AcceptedCount`, `BatchNum`, `ClientIp`, `ContentLength`, `ContentType`, and `CorrelationId`;
- the collection grid loads without invalid IDO, invalid table, or invalid property errors;
- no business data is returned yet, which is acceptable because the inbound table is still empty.

## Result

```text
IDO discovery      : PASS
Property discovery : PASS
Load Collection    : PASS
Empty-table result : EXPECTED
```

## Remaining Verification

The following metadata checks remain separate from this smoke-test screenshot:

```text
InboundId bound to inbound_id
InboundId key sequence = 1
RowPointer available
RecordDate available
SiteRef available
Object checked in
```

The first IDO is accepted as operational for collection loading.
