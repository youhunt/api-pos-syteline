# Patch 22 — Auto CO creates `co_bln_mst`

## Incident

UAT after Patch 21 produced a new Customer Order header with Blanket type, but the Blanket Order Lines form showed a blank item and `Blanket Quantity = 0`.

The missing object was not the header. The processor created `co_mst` and `coitem_mst` but never inserted rows into `dbo.co_bln_mst`.

## Tenant evidence

Tenant schema confirmed these `co_bln_mst` columns are available and relevant:

```text
site_ref
co_num
co_line
item
blanket_qty
cont_price
stat
u_m
blanket_qty_conv
cont_price_conv
ship_site
description
cost_conv
allow_on_pick_list
whse
```

A known-good Blanket Order (`R260904056`) showed the practical mapping:

```text
line 1: AC20002, blanket_qty=26, cont_price=57000, stat=O, u_m=TRY,
        blanket_qty_conv=26, cont_price_conv=57000, ship_site=Default
line 2: AC20003, blanket_qty=14, cont_price=60800, stat=O, u_m=TRY,
        blanket_qty_conv=14, cont_price_conv=60800, ship_site=Default
```

Tenant schema also confirmed `allow_on_pick_list` defaults to `1`, while this project requires it to be explicitly `0`.

## Patch

Apply Database:

```text
database/patches/csv-to-co/2026-09-15-smk069-22-create-blanket-lines.sql
```

The patch changes `dbo.SMK069ProcessCustomerOrderSp` so a new Auto CO creates one `co_bln_mst` row per staging line.

Mapping:

```text
co_bln_mst.site_ref           <- @SiteRef
co_bln_mst.co_num             <- generated @CreatedCoNum
co_bln_mst.co_line            <- staging co_line
co_bln_mst.item               <- staging item
co_bln_mst.blanket_qty        <- staging qty_ordered
co_bln_mst.cont_price         <- staging unit_price
co_bln_mst.stat               <- O
co_bln_mst.u_m                <- staging u_m, fallback item_mst.u_m
co_bln_mst.blanket_qty_conv   <- staging qty_ordered
co_bln_mst.cont_price_conv    <- staging unit_price
co_bln_mst.ship_site          <- @SiteRef
co_bln_mst.description        <- item_mst.description
co_bln_mst.cost_conv          <- item_mst.unit_cost
co_bln_mst.allow_on_pick_list <- 0
co_bln_mst.whse               <- staging/header warehouse
```

The patch validates that the number of inserted Blanket lines equals the staging line count. Any mismatch rolls back the order transaction.

## Existing broken UAT order repair

Patch 22 does not mass-update existing orders. It adds a safe existing-order repair path inside `SMK069ProcessCustomerOrderSp`:

- existing CO must already match the business `cust_po`;
- existing header must be Blanket type `B` (Patch 21 rule);
- existing `coitem_mst` line count and line content must match staging;
- if `co_bln_mst` currently has zero rows, the procedure creates the missing Blanket lines;
- if there are some Blanket rows but the count/content differs, processing fails instead of overwriting them.

For UAT source `R260904065`, the procedure may therefore be invoked directly after Patch 22 to repair the already-created Blanket header without creating another header.

## Verification

For a newly generated CO:

```sql
SELECT co_num, type, cust_po, consolidate
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CO_NUM>';
```

Expected:

```text
type        = B
cust_po     = business CustPo from payload
consolidate = 1
```

Blanket lines:

```sql
SELECT
    co_num,
    co_line,
    item,
    blanket_qty,
    cont_price,
    stat,
    u_m,
    blanket_qty_conv,
    cont_price_conv,
    ship_site,
    allow_on_pick_list,
    whse
FROM dbo.co_bln_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CO_NUM>'
ORDER BY co_line;
```

Expected for every line:

```text
item               = payload/staging item
blanket_qty        = payload/staging qty
cont_price         = payload/staging unit price
stat               = O
blanket_qty_conv   = qty (tenant-confirmed current sample behavior)
cont_price_conv    = price
allow_on_pick_list = 0
```

`coitem_mst` remains required as well and must keep `stat = O` and `consolidate = 1`.
