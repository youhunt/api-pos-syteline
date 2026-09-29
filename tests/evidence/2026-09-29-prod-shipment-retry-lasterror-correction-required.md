# PROD retry table targeted verification — LastError length correction required

Date: 2026-09-29
Environment: PROD
Object: dbo.ue_SMK069_shipment_retry_mst

Targeted verification:

```text
LastErrorBytes            2
RowPointerUniqueSemantic  PASS
RowPointerIndexName       IX_ue_SMK069_shipment_retry_mst_RowPointer
```

Interpretation:

- RowPointer uniqueness is correct semantically; the SQL Tables-generated unique index name is acceptable.
- LastError is currently nvarchar(1) in PROD (2 bytes).
- Current retry contract requires LastError nvarchar(1000) (2000 bytes).

Required correction:

Use SQL Tables / Mongoose metadata:

```text
LastError Length = 1000
```

Then use Update Current Table and re-run the targeted verification. Do not proceed to scheduler table/procedures until LastErrorBytes = 2000.
