# Evidence — SMK069 SP Compile Success and Missing Staging Runtime Result

Date: 31 July 2026
Database shown by user: `LENSA_SL_CSI_BAK`

## Tenant-confirmed procedure changes

The user simplified `dbo.SMK069ProcessCustomerOrderSp` by removing:

```text
@Sparepart
@PickupDate
@StartTime
@EndTime
```

The current generated Customer Order pattern is:

```text
COYYMM####
```

Portal-only unavailable `Uf_*` columns remain excluded.

## Compile result

The revised procedure compiled successfully in the tenant. The earlier alias-type conversion and missing-column compile errors are resolved.

## First runtime result

The procedure was executed and returned:

```text
Success      : 0
CreatedCoNum : NULL
Infobar      : Error 50003 pada line 72: Data staging untuk SiteRef dan source co_num tersebut tidak ditemukan.
```

The verification result grids for `co_mst` and `coitem_mst` were empty.

## Confirmed interpretation

This is a controlled validation failure, not a compile failure.

The supplied execution parameters did not match any staging group satisfying:

```sql
SiteRef = @SiteRef
AND LTRIM(RTRIM(co_num)) = @SourceCoNum
```

No Customer Order header or line was created.

## Next controlled step

Read the exact available staging groups first:

```sql
SELECT
    SiteRef,
    LTRIM(RTRIM(co_num)) AS SourceCoNum,
    COUNT(*) AS LineCount,
    MIN(process_status) AS MinStatus,
    MAX(process_status) AS MaxStatus
FROM dbo.ue_SMK069_temp_sales_mst
GROUP BY SiteRef, LTRIM(RTRIM(co_num))
ORDER BY SiteRef, SourceCoNum;
```

Use one exact returned `SiteRef + SourceCoNum` pair for the next execution. If no row is returned, staging is empty in the current database and must be populated before testing.

## Safety result

```text
Procedure compiled successfully
Controlled runtime validation executed
No co_mst row created
No coitem_mst row created
No trigger or constraint disabled
```
