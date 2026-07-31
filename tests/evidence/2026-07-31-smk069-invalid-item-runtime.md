# Evidence — SMK069 Invalid Item Runtime Validation

Date: 31 July 2026
Environment shown by user: `LENSA_SL_CSI_BAK`

## Runtime result

The compiled procedure `dbo.SMK069ProcessCustomerOrderSp` was executed against an existing staging order and returned:

```text
Success      : 0
CreatedCoNum : NULL
Infobar      : Error 50020 pada line 259: Item tidak ditemukan pada item_mst: TEST-ITEM-001
```

## Confirmed interpretation

The selected staging group exists and processing advanced beyond the initial staging lookup. The procedure then rejected the staged item because this tenant query produced no matching `item_mst` row for the same site and item value:

```sql
LEFT JOIN dbo.item_mst AS i
  ON i.site_ref = s.SiteRef
 AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
```

`TEST-ITEM-001` is therefore not a valid item for the staged `SiteRef` in this database.

This is a controlled validation failure. The procedure did not reach Customer Order header or line insertion.

## Next controlled step

Read actual item candidates for the same staging site, then replace only the dummy staging item with one exact returned item:

```sql
DECLARE @SiteRef SiteType = N'<EXACT_STAGING_SITE>';

SELECT TOP (20)
    site_ref,
    LTRIM(RTRIM(item)) AS item,
    description,
    u_m,
    unit_cost,
    matl_cost
FROM dbo.item_mst
WHERE site_ref = @SiteRef
  AND NULLIF(LTRIM(RTRIM(item)), N'') IS NOT NULL
ORDER BY item;
```

Before changing staging, verify the selected item and the staged row belong to the same `SiteRef`.

## Safety result

```text
Procedure compiled
Staging group found
Invalid item blocked before insertion
CreatedCoNum remained NULL
No trigger or constraint disabled
```
