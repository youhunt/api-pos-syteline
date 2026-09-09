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
- its `value2` result buffer is too small for a 3500-character procedure chunk.

The attempted 3500-character source dump failed with:

```text
String or binary data would be truncated in table
'dbo.ue_LNS00_QueryExecutionResults', column 'value2'.
```

Therefore do **not** dump the whole procedure in large chunks from this form.

## Query A — line 28 through 44 around failing line 36

Run this first. It is one pure `SELECT` and limits each source row to 200 characters:

```sql
SELECT
    q.LineNo,
    q.SourceLine
FROM
(
    SELECT
        ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS LineNo,
        LEFT(x.n.value('(text())[1]', 'nvarchar(4000)'), 200) AS SourceLine
    FROM
    (
        SELECT CONVERT(
            XML,
            N'<r><l>' +
            REPLACE(
                REPLACE(
                    (
                        SELECT m.definition AS [text()]
                        FROM sys.sql_modules AS m
                        WHERE m.object_id = OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')
                        FOR XML PATH(N'')
                    ),
                    CHAR(13),
                    N''
                ),
                CHAR(10),
                N'</l><l>'
            ) +
            N'</l></r>'
        ) AS DefinitionXml
    ) AS d
    CROSS APPLY d.DefinitionXml.nodes('/r/l') AS x(n)
) AS q
WHERE q.LineNo BETWEEN 28 AND 44
ORDER BY q.LineNo;
```

Expected output shape:

```text
LineNo | SourceLine
28     | ...
...
36     | <failing statement>
...
44     | ...
```

Copy all returned rows 28–44. This is enough to identify the exact statement around SQL Server-reported line 36 without exceeding the form result buffer.

If Query A itself is rejected by the tenant XML parser, use fallback Query A2 below.

## Query A2 — fallback small source chunks

This fallback returns only 200 characters per row:

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

This captures up to the first 6000 characters while staying far below the previous 3500-character per-row failure.

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

Do not create or apply the Complete fix until Query A/A2 is captured.

The likely failure class is a prefixed text outbound DN crossing into a numeric Shipment key, but the exact conversion must be proven from the tenant procedure body before modifying it.

The follow-up patch must:

- preserve the current Complete procedure body;
- change only the proven string/numeric crossing;
- keep the API log lifecycle intact;
- continue handling HTTP/business failures correctly;
- be one Apply Database batch with no `GO`;
- contain no retry or HTTP invocation.
