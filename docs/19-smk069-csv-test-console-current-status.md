# SMK069 CSV Test Console — Current Status

> Current contract reference:
>
> ```text
> docs/22-smk069-pos-contract-v2-20260827.md
> ```

## Current role

`SMK POS CSV TEST CONSOLE` is the functional/UAT harness for **POS Contract V2**.

```text
New Batch
-> Upload CSV
-> Save binary
-> Parse CSV V2
-> Import & Validate
-> Receive pricing/validation/co_num generation
-> valid rows enter temp status V
```

Customer Order creation remains separate:

```text
SMK API SALES ERROR PROCESSING
-> Process/Reprocess
-> co_mst type B
-> coitem_mst
-> co_bln_mst
-> temp status P
```

## V2 CSV contract

CSV/POS supplies:

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

CSV/POS does not supply:

```text
conum
unit_price
```

Receive supplies:

```text
co_num     = R + YYMM + 5-digit running number
unit_price = itemcustprice_mst effective pricing
```

Atomic order key:

```text
SiteRef + cust_po
```

## Parser V2 status

`SMK069ImportCsvFileSp` now:

- requires `cust_po`, `whse`, and `u_m`;
- no longer requires `conum` or `unit_price`;
- validates parser widths: custnum <= 7, cust_po <= 25, whse <= 8, item <= 30;
- stores `cust_po` on `ue_SMK069_pos_csv_upload_mst`;
- leaves legacy CSV-detail `conum` and `unit_price` unused for V2 processing.

Required patch:

```text
database/patches/2026-08-27-smk069-pos-contract-v2-csv-console.sql
```

Required secondary IDO property:

```text
ue_SMK069PosCsvUpload.CustPo -> cust_po
```

## Wrapper V2 status

`SMK069RunCsvTestBatchSp` now builds Receive JSON with:

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

plus optional test-harness fields such as SiteRef/due date/terms/tax/exchange rate when present.

It intentionally omits:

```text
conum
unit_price
```

so the CSV test path exercises the same server-side generation/pricing behavior as the production POS API.

## Upload event target

```text
0  Binary Value Action -> CsvFile
10 Collection Save -> primary
20 Call SMK069ImportCsvFileSp
30 Collection Refresh -> primary
40 Collection Refresh -> secondary
```

## Grid target

Visible parsed CSV columns:

```text
Row No
Customer
Order Date
Customer PO
Warehouse
Line
Item
Quantity
U/M
Upload Status
Result Message
```

Hide/remove legacy parsed columns:

```text
CSV conum
CSV unit_price
```

Generated `co_num` and resolved `unit_price` are visible downstream in inbound/temp.

## U/M rule V2

```text
payload u_m = item_mst.u_m
OR
u_m_conv_mst.item = payload item
AND (from_u_m = payload u_m OR to_u_m = payload u_m)
```

One invalid line marks the whole `SiteRef + cust_po` order Error.

## Current repository state

```text
[UPDATED] SMK069ImportCsvFileSp - Contract V2 parser
[UPDATED] SMK069RunCsvTestBatchSp - Contract V2 JSON wrapper
[ADDED]   CSV-detail cust_po schema patch
[UPDATED] SMK069_POS_CSV_Sample.csv
[UPDATED] CSV Test Console form documentation
[UAT CONFIRMED] Receive V2.1
[UAT CONFIRMED] Process V2 Blanket CO
```

## Remaining tenant actions

```text
[ ] Apply CSV-detail cust_po patch if not yet applied
[ ] Add/refresh ue_SMK069PosCsvUpload.CustPo
[ ] Apply updated SMK069ImportCsvFileSp
[ ] Apply updated SMK069RunCsvTestBatchSp
[ ] Update CSV detail grid columns
[ ] Test CSV -> inbound -> temp with V2 sample
[ ] Process generated co_num and reconcile coitem/co_bln
```
