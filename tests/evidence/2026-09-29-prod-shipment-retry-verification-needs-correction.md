# PROD retry table verification — correction/check required

Date: 2026-09-29
Environment: PROD
Object: dbo.ue_SMK069_shipment_retry_mst

Verification result:

```text
RetryTable              PASS
ColumnCount16           PASS
ShipmentIdNvarchar40    PASS
LastErrorNvarchar1000   FAIL
PrimaryKey              PASS
RowPointerUnique        FAIL
EnabledTriggers3        PASS
EmptyBaseline           PASS
```

Interpretation:

- table, column count, ShipmentId width, PK, Mongoose triggers, and empty baseline are correct;
- LastError physical width does not yet match the expected nvarchar(1000) contract;
- the RowPointer uniqueness check may be a naming mismatch because SQL Tables can generate a unique RowPointer index/constraint with a different name than the raw-DDL fallback. Verify semantics (unique + only RowPointer) rather than requiring a specific index name.

Do not proceed to scheduler procedures until LastError width is corrected and RowPointer uniqueness is confirmed semantically.
