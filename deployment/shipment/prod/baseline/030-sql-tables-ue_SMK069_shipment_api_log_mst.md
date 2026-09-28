# ue_SMK069_shipment_api_log_mst — PROD SQL Tables definition

Captured from current UAT on 2026-09-28.

Create this object through the **SQL Tables** form / Mongoose metadata path.
Do not use raw `CREATE TABLE` as the authoritative PROD creation method.

## Business columns

| Column | Data type | Length | Nullable | Default |
|---|---|---:|---|---|
| ShipmentId | nvarchar | 20 | No | |
| RequestDate | CurrentDateType | | Yes | getdate() |
| RequestJson | nvarchar | MAX | Yes | |
| ResponseDate | CurrentDateType | | Yes | |
| ResponseHttpCode | int | | Yes | |
| ResponseJson | nvarchar | MAX | Yes | |
| ProcessStatus | nvarchar | 1 | No | N'N' |
| ErrorMessage | nvarchar | 4000 | Yes | |
| RetryCount | int | | No | 0 |
| EndpointUrl | nvarchar | 1000 | Yes | |

## UAT physical evidence

UAT `sys.columns.max_length` returned:

- ShipmentId = 40 bytes => nvarchar(20)
- RequestJson = -1 => nvarchar(max)
- ResponseJson = -1 => nvarchar(max)
- ProcessStatus = 2 bytes => nvarchar(1)
- ErrorMessage = 8000 bytes => nvarchar(4000)
- EndpointUrl = 2000 bytes => nvarchar(1000)

## Standard Mongoose columns

The UAT table also contains the standard Mongoose columns before the business
columns:

```text
CreatedBy
UpdatedBy
CreateDate
RecordDate
RowPointer
NoteExistsFlag
InWorkflow
SiteRef
```

These should be generated/maintained by the SQL Tables mechanism.

UAT RowPointer characteristics:

```text
NOT NULL
not ROWGUIDCOL
unique constraint/index:
IX_ue_SMK069_shipment_api_log_mst_RowPointer
```

No database primary key was present.

## Standard triggers observed in UAT

```text
ue_SMK069_shipment_api_log_mstDel
ue_SMK069_shipment_api_log_mstInsert
ue_SMK069_shipment_api_log_mstUpdatePenultimate
```

All three were enabled. The Insert trigger is INSTEAD OF; the other two are
AFTER triggers.

After creating/updating the PROD table through SQL Tables, verify the same
trigger pattern exists and is enabled before importing dependent IDOs or
Shipment procedures.

## PROD verification query

```sql
SELECT TOP (20)
    t.name AS TriggerName,
    t.is_instead_of_trigger,
    t.is_disabled
FROM sys.triggers AS t
WHERE t.parent_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_log_mst')
  AND t.is_ms_shipped = 0
ORDER BY t.name
```
