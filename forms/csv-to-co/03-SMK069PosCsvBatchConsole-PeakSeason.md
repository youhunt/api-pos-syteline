# SMK POS CSV TO BLANKET CO — Peak Season Field

**Date:** 21 September 2026  
**Scope:** CSV / POS inbound → Blanket Customer Order

## Requirement

Add a read-only Peak Season flag to the CSV detail grid, immediately beside CustPo.

```text
Caption   : Peak Season
Field     : is_peak_season
Type      : INT
UI        : Checkbox
1         : checked
0         : unchecked
Read Only : True
Position  : beside CustPo
Default   : 0
```

The grid component must bind to the same detail collection that currently owns `cust_po`. That detail collection is backed by `dbo.ue_SMK069_pos_csv_upload_mst`, so Patch 27 adds the supporting `is_peak_season` column there.

## CSV contract

The CSV header is optional:

```text
is_peak_season
```

Accepted aliases:

```text
is_peak_season
is_peak_seson
peak_season
```

When omitted or blank, the parser stores:

```text
0
```

When supplied, only `0` or `1` is accepted.

The canonical CSV runner includes the flag in JSON sent to `dbo.SMK069ReceivePosSalesJsonSp`.

## Mongoose metadata

After Patch 27:

1. Resynchronize the IDO/collection backed by `ue_SMK069_pos_csv_upload_mst`.
2. Add a grid column beside the current CustPo column.
3. Bind it to property `is_peak_season` on that same detail collection.
4. Render as Checkbox.
5. Set Read Only = True.

Do not bind the CSV checkbox to a form variable; it must show the persisted row value.
