# Final CO Number, Cust PO Linkage, and Release Date

**Date:** 16 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order only

## Business request

Latest UAT feedback requires:

```text
1. SyteLine CO number in Error Processing must equal the actual CO created.
2. New CO format = P + YY + MM + DD + 3-digit daily running.
   Example: P260916001.
3. Released Date must equal Order Date.
4. cust_po is the business linkage carried downstream.
5. Legacy generated R... source co_num must not be used as the business key.
```

## Final identity model

```text
cust_po          = business order identity / linkage
                    example DEV4-233

temp.co_num      = actual SyteLine CO after successful processing
                    example P260916001

raw/source R...  = legacy/transient compatibility value only before processing;
                    it is not the downstream business key
```

No separate `syteline_co_num` column is required. Patch 23 was withdrawn/superseded.

## Patch 24 — final CO number + Release Date

Apply:

```text
database/patches/csv-to-co/2026-09-16-smk069-24-co-number-custpo-release-date.sql
```

Patch 24 provides:

```text
new CO number = PYYMMDD###
temp.co_num = actual generated/existing SyteLine CO after success
coitem_mst.release_date = order_date
safe historical relink of Processed temp rows to existing Blanket CO
```

Existing Customer Orders are not renumbered. If an older processed order already has `CO2609...`, its temp row is linked to that existing number rather than renaming the standard CO.

## Patch 25 — canonical Cust PO downstream linkage

Apply immediately after Patch 24:

```text
database/patches/csv-to-co/2026-09-16-smk069-25-canonical-custpo-linkage.sql
```

Patch 25 closes the remaining architectural gap:

```text
Batch discovery/pending check -> cust_po
Batch cursor                  -> cust_po
Batch -> per-order call       -> cust_po
Per-order staging reads       -> cust_po
Per-order staging updates     -> cust_po
Idempotency                   -> customer + cust_po
```

`SMK069ProcessCustomerOrderSp.@SourceCoNum` is retained only as a compatibility parameter name so existing method metadata/callers are not broken abruptly. New callers pass `cust_po` in that parameter. A legacy direct retry that still passes an old R... key can resolve it once to the staging `cust_po`; after that, all business processing is `cust_po` based.

## Released Date rule

For a newly created line:

```text
coitem_mst.release_date = @OrderDate
```

For an existing matching integration CO, missing/different line release dates are repaired to the CO header `order_date`.

## Numbering rule

For Order Date `2026-09-16`:

```text
P260916001
P260916002
P260916003
...
P260916999
```

The procedure keeps an application lock per `SiteRef + daily prefix` and reads the highest existing `co_mst.co_num` for that prefix before assigning the next 3-digit sequence.

## Historical rows

For existing processed rows such as:

```text
R260904069 / DEV4-233
R260904070 / DEV4-238
```

Patch 24 safely changes `temp.co_num` to the already-created SyteLine CO only when `SiteRef + customer + cust_po` resolves to exactly one Blanket CO. Existing standard CO numbers are not renamed.

## UAT after Patch 24 + Patch 25

Use one **new** valid PO. Do not use an already-processed business Cust PO to prove the new numbering format.

Verify staging and header:

```sql
SELECT
    t.SiteRef,
    t.cust_po,
    t.co_num AS TempSyteLineCo,
    t.order_date,
    t.process_status,
    t.processed_date,
    c.co_num AS ActualCoNum,
    c.[type],
    c.cust_po AS CoCustPo,
    c.order_date AS CoOrderDate,
    c.consolidate
FROM dbo.ue_SMK069_temp_sales_mst AS t
LEFT JOIN dbo.co_mst AS c
    ON c.site_ref = t.SiteRef
   AND c.co_num = t.co_num
WHERE t.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND t.cust_po = N'<NEW_CUST_PO>'
ORDER BY t.co_line;
```

Expected:

```text
t.cust_po          = payload business Cust PO
t.co_num            = PYYMMDD###
c.co_num            = same PYYMMDD###
c.type              = B
c.cust_po           = same business Cust PO
c.consolidate       = 1
process_status      = P
```

Verify CO line / Release Date:

```sql
SELECT
    c.co_num,
    c.cust_po,
    c.order_date,
    ci.co_line,
    ci.item,
    ci.due_date,
    ci.release_date,
    ci.stat,
    ci.consolidate
FROM dbo.co_mst AS c
INNER JOIN dbo.coitem_mst AS ci
    ON ci.site_ref = c.site_ref
   AND ci.co_num = c.co_num
WHERE c.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND c.cust_po = N'<NEW_CUST_PO>'
ORDER BY ci.co_line;
```

Expected:

```text
ci.release_date = c.order_date
ci.stat         = O
ci.consolidate  = 1
```

Verify Blanket lines:

```sql
SELECT
    b.co_num,
    b.co_line,
    b.item,
    b.blanket_qty,
    b.cont_price,
    b.stat,
    b.u_m,
    b.allow_on_pick_list,
    b.whse
FROM dbo.co_bln_mst AS b
WHERE b.site_ref = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND b.co_num = N'<PYYMMDD###>'
ORDER BY b.co_line;
```

Expected:

```text
stat               = O
allow_on_pick_list = 0
```

## Error Processing form

Final semantic binding:

```text
SyteLine CO Number = temp.co_num
Business/Source PO = temp.cust_po
```

The generated `R...` value is not a user-facing business reference and should not be used for downstream navigation/linkage.