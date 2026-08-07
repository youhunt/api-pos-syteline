# SMK069 CSV Test Console — Current Status

> This document is retained as the CSV-console status page. The authoritative end-to-end reference is now:
>
> ```text
> docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
> ```

## Current Role

`SMK POS CSV TEST CONSOLE` is a receive-and-validation test harness.

```text
New Batch
→ Upload CSV
→ Save binary
→ Parse rows
→ Import & Validate
→ valid rows enter temp status V
```

It does not create Customer Orders directly.

Customer Order creation occurs through:

```text
SMK API SALES ERROR PROCESSING
→ Process/Reprocess
→ co_mst type B
→ coitem_mst
→ co_bln_mst
```

## Collections

```text
Primary   : ue_SMK069PosCsvBatch
Secondary : ue_SMK069PosCsvUpload
Relation  : BatchId = FP(BatchId)
```

## Final UI Decisions

```text
File Name hidden
Upload should immediately save and parse
Parsed detail rows are the main upload-success indicator
Separate Parse button may remain as Re-parse fallback
Run Full Process renamed/treated as Import & Validate
```

## Final Upload Event Target

```text
0  Binary Value Action — CsvFile
10 Collection Save — primary
20 Generate Parse event / Call SMK069ImportCsvFileSp
30 Collection Refresh — primary
40 Collection Refresh — secondary
```

## Import & Validate Target

```text
SMK069RunCsvTestBatchSp
→ build canonical JSON
→ SMK069ReceivePosSalesJsonSp
→ raw inbound
→ mapping
→ validation including U/M
→ transfer valid order to temp
→ stop
```

## Validation Result

```text
valid order   → inbound T, temp V
invalid order → inbound E, no temp transfer
```

One invalid line invalidates all lines of the same `SiteRef + source co_num`.

## U/M Rule

```text
transaction U/M = item base U/M
or
valid Global/Item/Customer conversion exists
```

Vendor conversion is excluded.

## Downstream Processing

Source number:

```text
temp.co_num
co_mst.cust_po
```

Generated SyteLine number:

```text
temp.created_co_num
co_mst.co_num
coitem_mst.co_num
co_bln_mst.co_num
```

## Current Repository State

Committed:

```text
SMK069RunCsvTestBatchSp receive/validate-only wrapper
current form documentation
complete end-to-end documentation
U/M and Blanket correction evidence
```

Pending exact final tenant-source synchronization:

```text
SMK069ImportCsvFileSp
SMK069ReceivePosSalesJsonSp
SMK069ProcessCustomerOrderSp
```

## Pending Evidence

```text
[ ] Upload auto-parse event-chain screenshot/result
[ ] CreatedCoNum property/grid verification
[ ] U/M invalid-order negative evidence
[ ] co_mst type B verification
[ ] coitem/co_bln count reconciliation
[ ] 100-row/25-order UAT
```
