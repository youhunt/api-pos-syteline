# Peak Season flag — POS / CSV inbound

**Date:** 21 September 2026

## Confirmed requirement

```text
Payload field  : is_peak_season
SQL type       : INT
Default        : 0
1              : Peak Season
0              : Normal
```

Persist the flag in:

```text
dbo.ue_SMK069_pos_sales_inbound_mst
dbo.ue_SMK069_temp_sales_mst
```

The CSV test console also requires a supporting persisted field in:

```text
dbo.ue_SMK069_pos_csv_upload_mst
```

so the read-only grid can display and forward the same contract.

## Runtime plumbing

Patch 27 updates the public Receive wrapper after Core receive/validate:

```text
Payload JSON
  -> SMK069ReceivePosSalesJsonCoreSp
  -> PATCH-27 sync by cust_po + coline
       inbound.is_peak_season
       temp.is_peak_season
  -> quantity validation
  -> Auto CO
```

This avoids inventing a replacement for `SMK069ReceivePosSalesJsonCoreSp`, whose canonical tenant definition is still not present in the repository.

## CSV

Optional CSV field:

```text
is_peak_season
```

Aliases `is_peak_seson` and `peak_season` are accepted. Missing/blank defaults to 0. Values other than 0/1 are parser errors.

## Forms

`SMK API SALES ERROR PROCESSING`:

```text
Peak Season -> object.is_peak_season
read-only checkbox beside CustPo
```

`SMK POS CSV TO BLANKET CO`:

```text
Peak Season -> is_peak_season on the CSV detail collection
read-only checkbox beside CustPo
```

## Mapping view ownership

Eva confirmed that `is_peak_season` will also be added to:

```text
dbo.ue_SMK069_pos_sales_inbound_mapping_view
```

This view update is owned by Eva / the SMK side and is intentionally **not** included in Patch 27 or the repository canonical SQL at this time.

Our side only needs to ensure the source tables already contain the field so Eva's mapping view can consume it:

```text
ue_SMK069_pos_sales_inbound_mst.is_peak_season
ue_SMK069_temp_sales_mst.is_peak_season
```

Do not create a competing ALTER VIEW patch from this repository unless ownership changes explicitly.

## Quantity-multiple rule

Patch 27 transports/persists the flag.

Patch 29 makes POS-108 quantity validation select the `itemcust` mapping that matches the transaction Peak Season flag:

```text
itemcust.Uf_SMK069_is_peak_season = inbound.is_peak_season
```

The existing `SMK030_UomConvQty2/Getumcf` conversion formula is retained after the correct customer-item Peak/Normal mapping has been selected.

See:

```text
docs/csv-to-co/45-peak-season-aware-quantity-validation.md
```


## itemcust UET master configuration

Customer-item master configuration has also been extended through Mongoose UET:

```text
Uf_SMK069_is_peak_season   int, default 0
Uf_SMK069_pos_um           UMType / nvarchar(3)
Class                      SMK069_CL_itemcust
Extended table             itemcust_mst
Active                     1
Extend All Records         1
```

The fields are visible in **Customer Contracts** as:

```text
POS U/M
Is Peak Season?
```

Detailed configuration and production migration checklist:

```text
docs/csv-to-co/44-uet-itemcust-peak-season-pos-um.md
```

## Patch 35 — Peak flag before mapping snapshot

UAT on `DEV4-271` proved an ordering defect.

Payload/inbound after the request showed:

```text
AC20002B / 340 PCS / is_peak_season=1
AC20003B / 110 PCS / is_peak_season=1
```

The current canonical mapping view resolved:

```text
AC20042 / 17 TRY / 76000
AC20043 / 11 TRY / 76000
```

but temp and CO contained the Normal mapping:

```text
AC20002 / 22.66667 TRY / 57000
AC20003 / 13.75 TRY / 60800
```

The reason was execution order:

```text
Public Receive
→ Core Receive
   → #MapView materialized
   → temp created
→ Patch 27 set inbound.is_peak_season afterwards
```

So Core saw the inbound default `0` while the mapping view was being evaluated.

Patch 35 moves the Peak assignment into Core before `#MapView`:

```sql
is_peak_season =
    CASE
        WHEN TRY_CONVERT(INT, JSON_VALUE(i.raw_json, '$.is_peak_season')) = 1
        THEN 1
        ELSE 0
    END
```

New order:

```text
raw_json
→ inbound fields + is_peak_season
→ mapping view
→ #MapView
→ temp
→ CO
```

The post-Core Patch 27 sync remains for defensive/temp synchronization.
