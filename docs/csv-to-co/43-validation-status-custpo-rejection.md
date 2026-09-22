# ValidationStatus per item → atomic CustPO rejection

**Date:** 22 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Confirmed business requirement

Source:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view.ValidationStatus
```

Rules:

```text
ValidationStatus = V
→ item valid

ValidationStatus = N
→ item invalid
→ the entire CustPO is rejected
→ no Customer Order may be created for that CustPO
```

Validation is evaluated from item-level mapping rows, but the decision boundary is the whole `cust_po`.

Example:

```text
CustPO DEV4-300
line 1 / ITEM-A / V
line 2 / ITEM-B / N
line 3 / ITEM-C / V

Result:
DEV4-300 rejected completely.
No line from DEV4-300 enters Auto CO.
```

A different CustPO in the same batch can still continue when its rows are valid.

## Runtime placement

The gate is implemented in the canonical public receive procedure:

```text
SMK069ReceivePosSalesJsonCoreSp
  ↓
Peak Season payload propagation (Patch 27)
  ↓
ValidationStatus gate (Patch 28)
  ↓
Quantity multiple gate
  ↓
ProcessBatch
  ↓
Blanket CO
```

This ordering is intentional: the mapping view can consume the Peak Season flag added by Eva/SMK before ValidationStatus is evaluated.

## Error behavior

Patch 28 uses:

```text
[POS-109] CustPO ditolak karena minimal satu item memiliki ValidationStatus=N.
```

Every still-transferable inbound row in the rejected CustPO is marked Error. The message is worded at CustPO level so it does not falsely claim that every sibling item itself has status N.

Any temp rows already published as `V` by Core for that rejected CustPO are removed before ProcessBatch, so no CO can be created.

## Mapping-view ownership

`ue_SMK069_pos_sales_inbound_mapping_view` is maintained by Eva / SMK.

Patch 28 does **not** ALTER the view. Deployment guard:

```text
If ValidationStatus is not yet exposed by the view
→ Patch 28 stops with a clear prerequisite error
→ no partial SP replacement
```

## UAT cases

### Case A — all V

```text
CustPO A:
item 1 = V
item 2 = V
Expected: CustPO proceeds to normal downstream validation/CO processing.
```

### Case B — one N

```text
CustPO B:
item 1 = V
item 2 = N
Expected:
- whole CustPO B rejected
- inbound rows B = E
- no temp V rows remain for B
- no CO for B
- error contains POS-109
```

### Case C — mixed batch

```text
CustPO C = all V
CustPO D = contains N

Expected:
C may process successfully.
D rejected with POS-109.
```

## Verification query

```sql
SELECT
    v.SiteRef,
    v.source_system,
    v.batch_id,
    v.cust_po,
    v.ValidationStatus
FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
WHERE v.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND v.batch_id = N'<BATCH_ID>'
ORDER BY v.cust_po;
```

Then verify inbound:

```sql
SELECT
    i.cust_po,
    i.co_line,
    i.item,
    i.inbound_status,
    i.validation_msg
FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
WHERE i.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND i.batch_id = N'<BATCH_ID>'
ORDER BY i.cust_po, i.co_line;
```


## Patch 28 Rev.2

Rev.1 failed at compile time because the new `@MappingRejectedOrders` counter was referenced but not declared in the canonical Receive variable block.

Rev.2 fixes the canonical `SMK069ReceivePosSalesJsonSp` and redeploys it through the same Apply Database patch file.

Expected Apply Database success message:

```text
[PATCH-28 REV.2] SUCCESS - CustPO ditolak bila minimal satu item memiliki ValidationStatus=N.
```
