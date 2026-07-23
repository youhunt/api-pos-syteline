# IDO-003 — Raw Lines Smoke Test

## Object

```text
IDO Project : ue_SMKRSCPos
IDO         : ue_SMKRSCPosRawLines
Role        : Entity IDO
```

## Evidence

User supplied a web-client IDO Data Viewer screenshot showing:

- IDO `ue_SMKRSCPosRawLines` is selectable;
- properties including `BatchNum`, `ErrorMsg`, `Item`, `PosItemCode`, and `PosQty` are recognized;
- `Load Collection` completes without an invalid IDO/table/property error;
- the collection is currently empty, which is expected before CSV import test data is created.

## Result

```text
IDO discovery      : PASS
Property discovery : PASS
Load Collection    : PASS
Empty collection   : EXPECTED
```

## Notes

Composite key metadata still follows the table design:

```text
1. BatchNum
2. SourceRowNum
```

This evidence confirms the entity IDO is available to the SyteLine/Mongoose 10 web client after IDO cache refresh/session reload.
