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

Patch 27 only transports/persists the flag. It does **not** change POS-108 yet.

The chat requirement says Peak/Normal affects the applicable conversion/multiple (Peak 20, Normal 15), but Eva also stated the flag is used as additional mapping information in the inbound mapping view. Therefore the existing view/conversion definition must be audited before replacing the current `SMK030_UomConvQty2/Getumcf` validation.
