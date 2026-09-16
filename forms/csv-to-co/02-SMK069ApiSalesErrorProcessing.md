# SMK API SALES ERROR PROCESSING — Final Grid Binding

**Date:** 16 September 2026
**Scope:** CSV / POS inbound → Blanket Customer Order

## Proven UI issue

After the final identity change:

```text
ue_SMK069_temp_sales_mst.co_num = actual SyteLine CO number after success
ue_SMK069_temp_sales_mst.cust_po = business Customer PO
```

the Error Processing grid still uses the old component semantics.

Observed symptom:

```text
SyteLine CO Number column = blank
Source/POS Order No column = CO26090007 / P260916001 / P260916003 / ...
CustPo column = DEV4-233 / DEV4-243 / DEV4-238100 / ...
```

This proves the actual SyteLine CO number is already present in `co_num`; the form is displaying `co_num` under the wrong old column/caption while the `SyteLine CO Number` column is still bound to an obsolete/unpopulated source.

## Final form semantics

Use these bindings:

```text
SyteLine CO Number  -> object.co_num
CustPo              -> object.cust_po
```

Legacy `R...` Source/POS Order No is no longer a business field after successful processing and must not be used as the downstream linkage.

Because the form already has a `CustPo` column, the old `Source/POS Order No` column should be hidden/removed to avoid showing `co_num` twice or misleading the operator.

If the business still wants a user-facing Source/Business PO column, rename it to `Business/Source PO` and bind it to:

```text
object.cust_po
```

but then the existing separate `CustPo` column should be removed/hidden to avoid duplication.

## Recommended grid layout

```text
Site
Order Date
SyteLine CO Number   = object.co_num
Line
Customer
CustSeq
Name
CustPo               = object.cust_po
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

The top `CO Number` filter should filter the same property:

```text
co_num
```

so values such as `P260916003` can be used directly to locate the row.

## No database patch required

This is a Mongoose form binding/caption correction only. The backend is already persisting the actual SyteLine CO number to `ue_SMK069_temp_sales_mst.co_num` on success.

No SQL migration is required for this UI correction.
