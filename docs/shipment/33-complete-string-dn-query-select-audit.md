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

## Tenant UI limitation

`SMK Query Select Execution` in this tenant rejects procedural statements such as `DECLARE`, `SET`, `EXEC`, `BEGIN/END`, and `GO`.

Run each query below separately. Every block is a pure `SELECT`.

## Query A — exact Complete source in chunks

Run this first:

```sql
SELECT
    v.ChunkNo,
    SUBSTRING(
        m.definition,
        ((v.ChunkNo - 1) * 3500) + 1,
        3500
    ) AS SourceText
FROM sys.sql_modules AS m
CROSS JOIN
(
    VALUES
        (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)
) AS v(ChunkNo)
WHERE m.object_id = OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')
  AND LEN(m.definition) >= ((v.ChunkNo - 1) * 3500) + 1
ORDER BY v.ChunkNo;
```

Save/copy every returned `SourceText` row. This is the authoritative current tenant procedure body.

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

Expected historical shape is:

```text
@LogRowPointer uniqueidentifier
@HttpCode       int
@ResponseJson   nvarchar(max)
@IsSuccess      int
@Success        int OUTPUT
@Infobar        nvarchar OUTPUT
```

Do not patch from that historical assumption; capture current metadata.

## Query C — API log columns relevant to ShipmentId

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

This tells us whether the log stores the prefixed DN (`P96330`) as text and where Complete later crosses into the numeric standard Shipment key.

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

The likely failure class is a text prefixed outbound DN crossing into a numeric Shipment key, but the exact conversion must be proven from the tenant procedure body before modifying it.

The follow-up patch must:

- preserve the current Complete procedure body;
- change only the proven string/numeric crossing;
- keep the API log lifecycle intact;
- continue handling HTTP/business failures correctly;
- be one Apply Database batch with no `GO`;
- contain no retry or HTTP invocation.
