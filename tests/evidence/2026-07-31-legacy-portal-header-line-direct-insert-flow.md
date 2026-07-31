# Evidence — Legacy Portal Header and Line Direct-Insert Flow

Date: 31 July 2026

## Source Supplied by User

The legacy web portal creates a Customer Order in two application-side stages:

```text
1. Execute dbo.TDI_PortalEMotor_InsertCO
2. Read @co_num OUTPUT
3. Loop through COItemModel rows
4. INSERT each row into dbo.coitem_mst using the returned co_num
```

The application already retrieves the generated number with:

```csharp
co_num = Convert.ToString(cmd.Parameters["@co_num"].Value);
```

The same value is then used as `coitem_mst.co_num`, which establishes the header-to-line relationship.

## Confirmed Header Mapping

The supplied stored procedure inserts these `co_mst` fields:

```text
co_num
cust_num
cust_po
cust_seq
whse
order_date
curr_code
site_ref
contact
phone
terms_code
tax_code1
end_user_type
orig_site
include_tax_in_price
cost
matl_cost_t
price
Uf_date_pengambilan
Uf_StartTime
Uf_EndTime
```

It generates numbers using tenant-specific patterns:

```text
normal    : EMYYMM####
sparepart : EMPYYMM###
```

## Confirmed Line Mapping

The supplied portal code inserts these `coitem_mst` fields:

```text
co_num
co_line
item
qty_ordered
u_m
due_date
price
site_ref
whse
qty_ordered_conv
cust_seq
co_cust_num
ship_site
co_orig_site
description
cost
cgs_total
price_conv
matl_cost
cost_conv
matl_cost_conv
Uf_Item_price
Uf_net_price
Uf_price_aft_disc1
Uf_price_aft_disc2
Uf_price_aft_disc3
```

## Confirmed Relationship

The generated header number is sufficient to link all detail rows:

```text
co_mst.co_num = generated @co_num
coitem_mst.co_num = the same generated @co_num
```

No identity lookup or second database query is required because `@co_num` is generated before the header insert and returned as an output parameter.

## Risks in the Legacy Implementation

```text
- Header procedure and line inserts are not protected by one shared transaction.
- A header can remain committed when a later line insert fails.
- Line INSERT SQL is built by string concatenation.
- Decimal/date/string formatting is dependent on application formatting.
- SQL injection and quote-breaking are possible for text values.
- Header procedure globally disables triggers and disables/checks a foreign key.
- MAX(co_num) + 1 can produce duplicate numbers under concurrent execution.
```

## Selected Reuse Pattern

For the fastest safe implementation:

```text
BEGIN TRANSACTION
→ generate @co_num once under a concurrency-safe lock
→ insert co_mst
→ insert every coitem_mst row using the same @co_num
→ update staging with process result and generated number
→ COMMIT
```

On any failure:

```text
ROLLBACK
→ no partial header or lines
→ staging status becomes E through controlled error handling
```

Triggers and constraints remain enabled.
