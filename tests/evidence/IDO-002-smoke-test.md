# IDO-002 Smoke Test — ue_SMKRSCPosBatches

## Evidence

User supplied an IDO Data Viewer screenshot showing:

```text
IDO : ue_SMKRSCPosBatches
```

Recognized properties include:

```text
BatchNum
DiscountAmt
ErrorMsg
ExtBatchNum
GrossAmt
InputType
```

The collection loaded without invalid-IDO, invalid-table, or invalid-property errors. The empty grid is expected because the batch staging table does not yet contain data.

## Result

```text
IDO discovery      : PASS
Property discovery : PASS
Load Collection    : PASS
Empty collection   : EXPECTED
```

## Conclusion

The second entity IDO is available and queryable through IDO Data Viewer.
