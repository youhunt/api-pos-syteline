# SMK API SALES ERROR PROCESSING — Final Grid Binding

**Date:** 16 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Proven UI issue

The Error Processing form has a dedicated `SyteLine CO Number` field/property backed by:

```text
ue_SMK069_temp_sales_mst.created_co_num
```

The Auto CO processor previously returned the actual CO number through `@CreatedCoNum`, but did not persist that value into `created_co_num`. As a result, the grid column was blank even though a Customer Order had been created.

Observed example:

```text
cust_po         = DEV4-238100
actual CO       = P260916003
created_co_num  = NULL   <- wrong
```

## Backend fix — Patch 26

Apply:

```text
database/patches/csv-to-co/2026-09-16-smk069-26-persist-created-co-num.sql
```

Final behavior:

```text
new CO success:
created_co_num = @CreatedCoNum

existing/idempotent CO:
created_co_num = @ExistingCoNum
```

Patch 26 also safely backfills historical `Processed` staging rows when `SiteRef + customer + cust_po` resolves to exactly one Blanket CO.

## Final form semantics

Use these bindings:

```text
SyteLine CO Number  -> object.created_co_num
CustPo              -> object.cust_po
Peak Season          -> object.is_peak_season
```

`co_num` remains controlled by the active staging/process design and must not be used as the dedicated display property for the `SyteLine CO Number` column when `created_co_num` exists specifically for that purpose.

## Recommended grid layout

```text
Site
Order Date
SyteLine CO Number   = object.created_co_num
Source/POS Order No  = object.co_num   (only if the business still wants it shown)
Line
Customer
CustSeq
Name
CustPo               = object.cust_po
Peak Season           = object.is_peak_season (read-only checkbox)
Item
Quantity
U/M
Unit Price
Warehouse
Due Date
Terms
Tax Code
...
```

## Top filter

If the top `CO Number` filter is intended to search the actual SyteLine CO, it should filter:

```text
created_co_num
```

so values such as `P260916003` locate the row directly.

## Verification

After Patch 26:

```sql
SELECT
    SiteRef,
    co_num,
    cust_po,
    created_co_num,
    process_status,
    processed_date,
    processed_by
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po IN (N'DEV4-233', N'DEV4-238', N'DEV4-238100')
ORDER BY cust_po, co_line;
```

Expected for successful rows:

```text
created_co_num = actual SyteLine CO number
process_status = P
```


## Peak Season field — 21 September 2026

Requirement:

```text
Caption     : Peak Season
Binding     : object.is_peak_season
Control     : Checkbox
Checked     : value = 1
Unchecked   : value = 0
Read Only   : True
Position    : immediately beside CustPo
Default SQL : 0
```

After Patch 27, resynchronize the IDO `ue_SMK069TempSales` so the new property is available to the form. The checkbox is display-only; operators must not change the flag from Error Processing.


## CustSeq / Name derived IDO properties — 23 September 2026

Tenant SQL verification proved the correct relationship after Auto CO processing:

```text
temp.co_num     = P260923002 / P260923003
mapping.co_num  = R260904065
```

Therefore `co_num` must **not** be part of the IDO relationship between
`ue_SMK069_temp_sales_mst` and
`ue_SMK069_pos_sales_inbound_mapping_view`.

Use:

```text
Primary alias:
  ts = ue_SMK069_temp_sales_mst

Secondary alias:
  posin = ue_SMK069_pos_sales_inbound_mapping_view
  LEFT OUTER JOIN
    posin.SiteRef  = ts.SiteRef
    posin.cust_num = ts.cust_num
    posin.cust_po  = ts.cust_po
    posin.co_line  = ts.co_line

Secondary alias:
  custaddr = custaddr_mst
  LEFT OUTER JOIN
    custaddr.cust_num = ts.cust_num
    custaddr.cust_seq = posin.cust_seq
```

Do not use:

```text
posin.co_num = ts.co_num
```

because `ts.co_num` becomes the actual SyteLine CO after processing while the
mapping view can still carry the technical/source R-number.

SQL proof:

```text
DEV4-271:
  temp CO       = P260923002
  mapping CO    = R260904065
  cust_seq      = 164
  customer name = DEV4. DEV API POS Integration Testing
  is_peak_season= 1

DEV4-272:
  temp CO       = P260923003
  mapping CO    = R260904065
  cust_seq      = 164
  customer name = DEV4. DEV API POS Integration Testing
  is_peak_season= 0
```

The secondary-table columns must also be explicitly exposed as IDO properties.
Recommended property names:

```text
PosCustSeq
  source table alias = posin
  source column      = cust_seq

CustomerName
  source table alias = custaddr
  source column      = name
```

Then bind the grid:

```text
CustSeq -> object.PosCustSeq
Name    -> object.CustomerName
Peak    -> object.is_peak_season
```

Resynchronizing the primary table alone does not automatically create these
secondary-table properties.
