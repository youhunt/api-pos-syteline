# 34 — Complete Shipment prefixed DN fix

> Date: 9 September 2026  
> Scope: **Shipment Outbound SyteLine → POS API only**  
> Patch: `database/patches/shipment/2026-09-09-smk069-15-fix-complete-shipment-dn-string.sql`

## 1. Proven tenant root cause

Queue failures:

```text
P96330 HTTP 404
Complete Shipment exception:
Error converting data type nvarchar to bigint.
dbo.SMK069CompleteShipmentSendSp:36

P96332 HTTP 404
Complete Shipment exception:
Error converting data type nvarchar to bigint.
dbo.SMK069CompleteShipmentSendSp:36
```

The exact current tenant Complete source was captured through Query Select in 200-character chunks and preserved as:

```text
database/procedures/shipment/SMK069CompleteShipmentSendSp.tenant-2026-09-09.sql
```

It contains the actual failing contract:

```sql
DECLARE @ShipmentId BIGINT;

SELECT
    @ShipmentId = ShipmentId
FROM dbo.ue_SMK069_shipment_api_log_mst
WHERE SiteRef = @Site
  AND RowPointer = @LogRowPointer;
```

The API log `ShipmentId` now contains the outbound DN string, for example `P96330`, so assignment into BIGINT fails before Complete can finalize the log or update `shipment_mst`.

## 2. Current tenant DN contract

A targeted current-View Query Select returned:

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS nvarchar(10)
) AS DN_No
```

Therefore the prefix is four characters and is part of the outbound DN contract:

```text
PLG shipment_id 30  -> P96330
PLG shipment_id 31  -> P96331
PLG shipment_id 32  -> P96332

non-PLG shipment_id 30 -> R97530
```

Important consequence:

```text
P96330 != shipment_id 96330
P96330  = prefix P963 + shipment_id 30
```

This is why simply stripping only the leading `P` would be incorrect.

## 3. Patch 15 design

Patch 15 changes only `dbo.SMK069CompleteShipmentSendSp`.

The Complete procedure now keeps two separate values:

```text
@ShipmentDn NVARCHAR(40)  -> external/outbound DN, e.g. P96330
@ShipmentId BIGINT        -> internal SyteLine shipment_mst key, e.g. 30
```

The log is read into `@ShipmentDn` as text.

The numeric standard key is resolved against `shipment_mst` using the exact current tenant prefix rule:

```sql
CAST(
    CONCAT(
        IIF(sh.whse = 'PLG', 'P963', 'R975'),
        sh.shipment_id
    )
    AS NVARCHAR(40)
) = @ShipmentDn
```

A numeric-only fallback is retained for historical API-log rows created before prefixed DNs were introduced:

```sql
TRY_CONVERT(BIGINT, @ShipmentDn)
```

Success/error updates to `shipment_mst` continue to use the numeric `@ShipmentId`.

Infobar messages continue to show the outbound DN (`P96330` / `R975xx`) rather than the internal numeric key.

## 4. Source control

Pre-fix tenant capture:

```text
database/procedures/shipment/SMK069CompleteShipmentSendSp.tenant-2026-09-09.sql
```

Fixed canonical procedure source:

```text
database/procedures/shipment/SMK069CompleteShipmentSendSp.sql
```

Apply patch:

```text
database/patches/shipment/2026-09-09-smk069-15-fix-complete-shipment-dn-string.sql
```

The patch verifies both:

- the old `DECLARE @ShipmentId BIGINT` + `@ShipmentId = ShipmentId` failure class still exists before first apply;
- the current Shipment View still exposes P963/R975 + `sh.shipment_id` DN behavior.

It is idempotent through marker:

```text
SMK069-COMPLETE-DN-STRING-R1
```

## 5. Apply Database

Run Patch 15 through Infor Apply Database.

Expected messages:

```text
OK - Patch 15 applied.
Complete sekarang membaca outbound DN sebagai NVARCHAR.
P963/R975 DN dipetakan ke numeric shipment_mst.shipment_id memakai current tenant View contract.
Contoh: P96330 -> shipment_id 30, BUKAN 96330.
Patch ini TIDAK Reset Retry dan TIDAK melakukan HTTP call.
JANGAN retry sampai HTTP 404 endpoint juga dibereskan.
```

Patch 15 does not send a Shipment and does not consume retry attempts.

## 6. Query Select verification

The tenant Query Select form wraps supplied SQL, so use a simple SELECT with no `ORDER BY` and no trailing semicolon:

```sql
SELECT
    CASE
        WHEN CHARINDEX(
            N'SMK069-COMPLETE-DN-STRING-R1',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')), N'')
        ) > 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS Patch15Marker,

    CASE
        WHEN CHARINDEX(
            N'@ShipmentId = ShipmentId',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')), N'')
        ) = 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS OldBigintAssignmentRemoved,

    CASE
        WHEN CHARINDEX(
            N'@ShipmentDn',
            ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069CompleteShipmentSendSp', N'P')), N'')
        ) > 0
        THEN N'PASS'
        ELSE N'FAIL'
    END AS StringDnPresent
```

Expected:

```text
Patch15Marker              PASS
OldBigintAssignmentRemoved PASS
StringDnPresent            PASS
```

## 7. Retry gate remains closed because HTTP 404 is separate

Patch 15 resolves the Complete exception, but it does **not** resolve:

```text
HTTP 404
Response=404 page not found
```

Therefore do not reset/retry P96330, P96331, or P96332 yet merely because Patch 15 passes.

Next gate is the configured Shipment `EndpointUrl` versus the known-good POS `infor_dn` route.

Only after endpoint root cause is corrected:

```text
Max/Run = 1
Reset ONE DN
controlled UAT
verify HTTP -> Complete -> API log -> retry state -> Api_post
```
