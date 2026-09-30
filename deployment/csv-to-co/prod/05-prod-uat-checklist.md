# SMK069 PROD UAT Checklist

**Date:** 24 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order only

Use **approved PROD-safe master data**. Do not reuse DEV-only `DEV4` test master data unless it also exists and is authorized in PROD.

Every changed/new test transaction must use a **new BatchId and new CustPO** unless the test is explicitly an idempotent replay or duplicate-CustPO test.

## UAT 0 — Smoke / metadata

Confirm:

```text
[ ] SMK API SALES ERROR PROCESSING opens
[ ] SMK POS CSV TO BLANKET CO opens
[ ] Customer Contracts shows POS U/M
[ ] Customer Contracts shows Is Peak Season?
[ ] Error Processing Peak checkbox renders 0/1 correctly
[ ] Error Processing CustSeq and Name populate correctly
[ ] CSV detail Peak checkbox renders correctly
```

## UAT 1 — New valid Normal order

Input:

```text
new BatchId
new CustPO
is_peak_season = 0
all lines valid according to mapping view
```

Expected API:

```text
Success=true
ProcessedOrders=1
ProcessErrors=0
CreatedCoNums contains one PYYMMDD### CO
```

Verify inbound:

```sql
SELECT
    batch_id,
    cust_po,
    co_line,
    item,
    qty_ordered,
    u_m,
    is_peak_season,
    inbound_status,
    validation_msg
FROM dbo.ue_SMK069_pos_sales_inbound_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po = N'<NORMAL_CUST_PO>'
ORDER BY co_line;
```

Expected:

```text
is_peak_season = 0
inbound_status = T
validation_msg = blank
```

## UAT 2 — New valid Peak order

Input:

```text
new BatchId
new CustPO
is_peak_season = 1
```

Before submitting, confirm the mapping view/master has a Peak configuration for the chosen customer-item.

After submit, verify that the mapping used in temp is the **Peak mapping**, not Normal.

```sql
SELECT
    t.created_co_num,
    t.cust_po,
    t.co_line,
    t.item,
    t.qty_ordered,
    t.u_m,
    t.unit_price,
    t.is_peak_season,
    t.process_status
FROM dbo.ue_SMK069_temp_sales_mst AS t
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.cust_po = N'<PEAK_CUST_PO>'
ORDER BY t.co_line;
```

Expected:

```text
is_peak_season = 1
mapped item/U/M/qty/price = mapping view Peak result
process_status = P
```

This specifically validates the Patch-35 current-state behavior:

```text
payload Peak flag
→ inbound Peak flag
→ mapping view
→ temp
→ CO
```

## UAT 3 — Mapping snapshot = Customer Order

For a successful test CO:

```sql
SELECT
    co_num,
    co_line,
    item,
    qty_ordered,
    u_m,
    price,
    co_release,
    release_date,
    stat,
    consolidate
FROM dbo.coitem_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO>'
ORDER BY co_line;
```

```sql
SELECT
    co_num,
    co_line,
    item,
    blanket_qty,
    u_m,
    cont_price,
    stat,
    allow_on_pick_list,
    whse
FROM dbo.co_bln_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO>'
ORDER BY co_line;
```

Expected:

```text
coitem.item/qty/u_m/price = temp snapshot
co_bln.item/qty/u_m/price = temp snapshot
coitem.stat = O
coitem.co_release = 1
coitem.consolidate = 1
co_bln.stat = O
co_bln.allow_on_pick_list = 0
```

## UAT 4 — Header contract

```sql
SELECT
    co_num,
    type,
    cust_num,
    cust_seq,
    cust_po,
    order_date,
    whse,
    consolidate
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND co_num = N'<CREATED_CO>';
```

Expected:

```text
co_num      = PYYMMDD###
type        = B
cust_po     = business CustPO
consolidate = 1
```

## UAT 5 — Release flag and Release Date

For every line:

```text
coitem_mst.co_release = 1
coitem_mst.release_date = co_mst.order_date
```

Use:

```sql
SELECT
    c.co_num,
    c.order_date,
    i.co_line,
    i.co_release,
    i.release_date
FROM dbo.co_mst AS c
INNER JOIN dbo.coitem_mst AS i
    ON i.site_ref = c.site_ref
   AND i.co_num = c.co_num
WHERE c.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.co_num = N'<CREATED_CO>'
ORDER BY i.co_line;
```

## UAT 6 — Error Processing traceability

For the successful CustPO:

```sql
SELECT
    co_num,
    created_co_num,
    cust_po,
    co_line,
    item,
    qty_ordered,
    u_m,
    is_peak_season,
    process_status,
    processed_date,
    processed_by
FROM dbo.ue_SMK069_temp_sales_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po = N'<CUST_PO>'
ORDER BY co_line;
```

Expected:

```text
created_co_num = actual PYYMMDD### CO
cust_po        = business CustPO
process_status = P
```

Form must show the same actual CO number under **SyteLine CO Number**.

## UAT 7 — Original request replay / idempotency

Resend the **exact same original BatchId and exact same payload**.

Expected:

```text
no second Customer Order
existing CO remains the only CO for the CustPO
request is handled idempotently
```

Verify:

```sql
SELECT
    cust_po,
    COUNT(DISTINCT co_num) AS co_count
FROM dbo.co_mst
WHERE site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po = N'<CUST_PO>'
GROUP BY cust_po;
```

Expected:

```text
co_count = 1
```

## UAT 8 — New BatchId + existing CustPO

Use:

```text
unused/new BatchId
existing already-processed CustPO
```

Expected:

```text
POS-204
Success=false
ProcessedOrders=0
no new CO
```

The message must clearly state that the CustPO has already been registered/processed and a new BatchId does not create a new business order.

## UAT 9 — Quantity multiple rejection

Use a **new CustPO** with a quantity that violates the configured Peak/Normal customer-item/U/M multiple.

Expected:

```text
POS-108 on root invalid line
whole CustPO rejected atomically
no CO created
```

Sibling lines may show POS-203.

Verify:

```sql
SELECT
    cust_po,
    co_line,
    item,
    qty_ordered,
    u_m,
    is_peak_season,
    inbound_status,
    validation_msg
FROM dbo.ue_SMK069_pos_sales_inbound_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND cust_po = N'<POS108_CUST_PO>'
ORDER BY co_line;
```

No matching CO must exist in `co_mst`.

## UAT 10 — ValidationStatus=N atomic rejection

Prepare a new CustPO where at least one mapping-view line returns:

```text
ValidationStatus = N
```

Expected:

```text
POS-109
entire CustPO rejected
no CO
```

If another line is otherwise valid, it must not be processed independently.

## UAT 11 — CSV one-hit Normal

CSV must contain the required Contract V2 fields:

```text
custnum
order_date
cust_po
whse
coline
item
qty_ordered
u_m
```

Optional:

```text
is_peak_season
```

Flow:

```text
New Batch
→ Upload CSV to Blanket CO
→ choose file
→ parse
→ canonical Receive
→ Blanket CO
```

Expected:

```text
CSV batch success
actual PYYMMDD### CO
same header/line/blanket acceptance as API path
```

## UAT 12 — CSV Peak

Use CSV header:

```text
is_peak_season
```

with value:

```text
1
```

Aliases accepted by parser:

```text
is_peak_season
is_peak_seson
peak_season
```

Expected:

```text
CSV detail Peak checkbox checked
inbound Peak=1
temp Peak=1
Peak mapping used
CO uses Peak mapped snapshot
```

## Final sign-off

```text
[ ] Normal API positive path PASS
[ ] Peak API positive path PASS
[ ] Header Blanket contract PASS
[ ] coitem contract PASS
[ ] co_bln contract PASS
[ ] Release Date PASS
[ ] created_co_num/display PASS
[ ] original replay PASS
[ ] POS-204 duplicate PASS
[ ] POS-108 quantity rejection PASS
[ ] POS-109 mapping rejection PASS
[ ] CSV Normal PASS
[ ] CSV Peak PASS
[ ] Error Processing form PASS
[ ] Customer Contracts UET PASS
```
