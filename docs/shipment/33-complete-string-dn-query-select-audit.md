# 33 — Complete Shipment string-DN audit via SMK Query Select

> Date: 9 September 2026  
> Scope: Shipment Outbound SyteLine → POS API  
> Status: read-only tenant capture before Complete patch

## Current blocker

P96330 and P96332 reached HTTP and then Complete failed with:

```text
Error converting data type nvarchar to bigint.
dbo.SMK069CompleteShipmentSendSp:36
```

Patch 14 Rev.2 is already verified PASS/PASS for P96331's missing-DOC_NO Build gate. Do not retry yet because Complete is a shared path.

## Tenant UI limitations confirmed

`SMK Query Select Execution` in this tenant:

- rejects procedural statements such as `DECLARE`, `SET`, `EXEC`, `BEGIN/END`, and `GO`;
- stores query output through `dbo.ue_LNS00_QueryExecutionResults`;
- its `value2` result buffer is too small for a 3500-character procedure chunk;
- also rejects the attempted `ROW_NUMBER` + XML-nodes line-splitting query near alias `LineNo`.

Therefore use only simple pure `SELECT` statements with short scalar output values.

## Query A — authoritative Complete source in 200-character chunks

This pattern already passed the Query Select parser; only the old 3500-character value was too large. Run:

```sql
SELECT
    v.ChunkNo,
    SUBSTRING(
        m.definition,
        ((v.ChunkNo - 1) * 200) + 1,
        200
    ) AS SourceText
FROM sys.sql_modules AS m
CROSS JOIN
(
    VALUES
        (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
        (11),(12),(13),(14),(15),(16),(17),(18),(19),(20),
        (21),(22),(23),(24),(25),(26),(27),(28),(29),(30)
) AS v(ChunkNo)
WHERE m.object_id = OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')
  AND LEN(m.definition) >= ((v.ChunkNo - 1) * 200) + 1
ORDER BY v.ChunkNo;
```

Each row is at most 200 characters, well below the failed 3500-character value. Copy all returned `ChunkNo` + `SourceText` rows. Up to 6000 source characters are captured.

If `value2` still truncates at 200 on this tenant, change both occurrences of `200` to `120` and extend the VALUES list as needed. Do not switch back to large chunks.

## Query B — current Complete parameter metadata

```sql
SELECT
    p.parameter_id,
    p.name AS ParameterName,
    TYPE_NAME(p.user_type_id) AS UserTypeName,
    TYPE_NAME(p.system_type_id) AS SystemTypeName,
    p.max_length,
    p.precision,
    p.scale,
    p.is_output
FROM sys.parameters AS p
WHERE p.object_id = OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')
ORDER BY p.parameter_id;
```

Historical shape was:

```text
@LogRowPointer uniqueidentifier
@HttpCode       int
@ResponseJson   nvarchar(max)
@IsSuccess      int
@Success        int OUTPUT
@Infobar        nvarchar OUTPUT
```

Do not patch from that historical assumption; capture current metadata.

## Query C — API log columns

```sql
SELECT
    c.column_id,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS UserTypeName,
    TYPE_NAME(c.system_type_id) AS SystemTypeName,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_log_mst', N'U')
ORDER BY c.column_id;
```

## Query D — standard Shipment key type

```sql
SELECT
    c.column_id,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS UserTypeName,
    TYPE_NAME(c.system_type_id) AS SystemTypeName,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.shipment_mst', N'U')
  AND c.name IN (N'shipment_id', N'Api_post', N'Api_post_date')
ORDER BY c.column_id;
```

## Patch decision

Do not create or apply the Complete fix until Query A is captured.

The likely failure class is a prefixed text outbound DN crossing into a numeric Shipment key, but the exact conversion must be proven from the tenant procedure body before modifying it.

The follow-up patch must:

- preserve the current Complete procedure body;
- change only the proven string/numeric crossing;
- keep the API log lifecycle intact;
- continue handling HTTP/business failures correctly;
- be one Apply Database batch with no `GO`;
- contain no retry or HTTP invocation.
