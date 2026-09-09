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
- rejects the attempted `ROW_NUMBER` + XML-nodes line-splitting query;
- wraps the supplied SELECT in another query/derived table, therefore a plain trailing `ORDER BY` is rejected unless paired with TOP/OFFSET/FOR XML.

Therefore use only simple pure `SELECT` statements, short scalar output values, and **no trailing ORDER BY**. Returned rows may be visually unsorted; use the explicit numeric key (`ChunkNo`, `parameter_id`, `column_id`) to identify them.

## Query A — authoritative Complete source in 200-character chunks

Run exactly this version **without ORDER BY**:

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
  AND LEN(m.definition) >= ((v.ChunkNo - 1) * 200) + 1;
```

Each row is at most 200 characters. Copy all returned `ChunkNo` + `SourceText` rows; they do not need to be displayed in numeric order because `ChunkNo` identifies the original position.

If `value2` still truncates at 200 on this tenant, change both occurrences of `200` to `120` and extend the VALUES list as needed. Do not switch back to large chunks.

## Query A0 — targeted context if full chunk capture is inconvenient

This query returns short contexts around the first `shipment_id`, `ShipmentId`, and `DN_No` tokens in the current Complete source. It is also a pure SELECT and has no ORDER BY:

```sql
SELECT
    CHARINDEX(N'shipment_id', LOWER(m.definition)) AS ShipmentIdColumnPos,
    CASE
        WHEN CHARINDEX(N'shipment_id', LOWER(m.definition)) > 0
        THEN SUBSTRING(
                 m.definition,
                 CASE
                     WHEN CHARINDEX(N'shipment_id', LOWER(m.definition)) > 80
                     THEN CHARINDEX(N'shipment_id', LOWER(m.definition)) - 80
                     ELSE 1
                 END,
                 180
             )
        ELSE N''
    END AS ShipmentIdContext,
    CHARINDEX(N'shipmentid', LOWER(m.definition)) AS ShipmentIdTokenPos,
    CHARINDEX(N'dn_no', LOWER(m.definition)) AS DnNoPos
FROM sys.sql_modules AS m
WHERE m.object_id = OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P');
```

If Query A works, it remains the preferred evidence because it preserves the complete current tenant body in small pieces.

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
WHERE p.object_id = OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P');
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
WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_shipment_api_log_mst', N'U');
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
  AND c.name IN (N'shipment_id', N'Api_post', N'Api_post_date');
```

## Patch decision

Do not create or apply the Complete fix until Query A (or at minimum A0 plus metadata C/D) identifies the exact string/numeric crossing.

The likely failure class is a prefixed text outbound DN crossing into a numeric Shipment key, but the exact conversion must be proven from the tenant procedure body before modifying it.

The follow-up patch must:

- preserve the current Complete procedure body;
- change only the proven string/numeric crossing;
- keep the API log lifecycle intact;
- continue handling HTTP/business failures correctly;
- be one Apply Database batch with no `GO`;
- contain no retry or HTTP invocation.
