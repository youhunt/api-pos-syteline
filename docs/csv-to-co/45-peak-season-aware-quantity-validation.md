# Peak Season aware quantity validation

**Date:** 22 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Problem proven in UAT

Payload:

```text
cust_po = DEV4-256
is_peak_season = 0
line 1 = AC20002B / 270 PCS
line 2 = AC20003B / 32 PCS
```

returned `POS-108`.

The canonical quantity validation was already reading inbound rows, but its `itemcust` join used only:

```text
cust_item
cust_num
```

It did not include the newly-created customer-item UET Peak Season flag. If customer/item has different `itemcust` mappings for Peak and Normal conditions, the validation can resolve the wrong mapping row.

## Final quantity mapping predicate

Patch 29 changes the `itemcust` join to:

```sql
JOIN dbo.itemcust AS ic
  ON ic.cust_item = i.item
 AND ic.cust_num = c.cust_num
 AND ISNULL(ic.Uf_SMK069_is_peak_season, 0)
     = ISNULL(i.is_peak_season, 0)
```

Then the existing conversion formula remains:

```sql
CAST(
    ISNULL(
        dbo.SMK030_UomConvQty2(
            i.qty_ordered,
            ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
            'To Base'
        ),
        0
    )
    AS decimal(23,5)
)
```

Validation remains invalid when:

```text
converted qty <> FLOOR(converted qty)
```

Result:

```text
POS-108
whole CustPO rejected
no CO created
```

## Important inbound behavior

A `POS-108` response does **not** mean the request never entered inbound.

Runtime order is:

```text
Receive Core
  → inbound rows created
  → Peak Season propagated
  → ValidationStatus gate
  → quantity validation
  → invalid rows changed T → E
  → any temp V rows for rejected CustPO removed
  → no CO
```

Therefore a rejected request should normally still be queryable in:

```text
dbo.ue_SMK069_pos_sales_inbound_mst
```

with:

```text
inbound_status = E
validation_msg = POS-108...
```

## Verification query

```sql
SELECT
    i.cust_po,
    i.co_line,
    i.item,
    i.qty_ordered,
    i.u_m,
    i.is_peak_season,
    ic.item AS mapped_item,
    ic.Uf_SMK069_is_peak_season AS itemcust_peak,
    CAST(
        ISNULL(
            dbo.SMK030_UomConvQty2(
                i.qty_ordered,
                ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
                'To Base'
            ),
            0
        )
        AS decimal(23,5)
    ) AS qty_base,
    CASE
        WHEN CAST(
            ISNULL(
                dbo.SMK030_UomConvQty2(
                    i.qty_ordered,
                    ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
                    'To Base'
                ),
                0
            )
            AS decimal(23,5)
        ) <> FLOOR(
            CAST(
                ISNULL(
                    dbo.SMK030_UomConvQty2(
                        i.qty_ordered,
                        ISNULL(dbo.Getumcf(i.u_m, ic.item, '', ''), 1),
                        'To Base'
                    ),
                    0
                )
                AS decimal(23,5)
            )
        )
        THEN 'WARNING: Quantity tidak sesuai dengan kelipatan'
        ELSE 'OK'
    END AS ValidationStatus
FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
JOIN dbo.custaddr AS c
  ON i.cust_num = LEFT(c.name, 4)
 AND c.cust_num LIKE N'PH%'
 AND c.cust_seq <> 0
LEFT JOIN dbo.customer AS cs
  ON cs.cust_num = c.cust_num
 AND cs.cust_seq = 0
JOIN dbo.itemcust AS ic
  ON ic.cust_item = i.item
 AND ic.cust_num = c.cust_num
 AND ISNULL(ic.Uf_SMK069_is_peak_season, 0)
     = ISNULL(i.is_peak_season, 0)
WHERE i.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND i.cust_po = N'<CUST_PO>'
ORDER BY i.co_line;
```

## Deployment

Apply:

```text
database/patches/csv-to-co/2026-09-22-smk069-29-peak-season-aware-qty-validation.sql
```

Expected:

```text
[PATCH-29] SUCCESS - POS-108 quantity validation memakai itemcust sesuai is_peak_season.
```
