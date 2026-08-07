# SMK069 POS CSV Test Console

## Identity

```text
Display Caption      : SMK POS CSV TEST CONSOLE
Primary Collection   : ue_SMK069PosCsvBatch
Secondary Collection : ue_SMK069PosCsvUpload
Relation              : BatchId = FP(BatchId)
Purpose               : Functional CSV-to-sales receive and validation test harness
```

This form is a controlled UAT console. It receives CSV, parses rows, constructs canonical JSON, validates business data, and transfers fully valid orders to `dbo.ue_SMK069_temp_sales_mst`.

It does **not** create the Customer Order directly. Blanket Customer Order creation is performed from `SMK API SALES ERROR PROCESSING` or by invoking `SMK069ProcessCustomerOrderSp` once per source order.

## Final End-to-End Position

```text
CSV Console
→ csv_file
→ parsed CSV detail
→ Import & Validate
→ inbound validation
→ temp sales, status V

Error Processing
→ Process/Reprocess
→ co_mst type B
→ coitem_mst
→ co_bln_mst
→ temp status P + created_co_num
```

Full documentation:

```text
docs/20-smk069-csv-to-blanket-customer-order-end-to-end.md
```

## Header Controls

Business-visible controls:

```text
Batch Id
Source System
Batch Status
Result Message
Received Rows
Total Orders
Valid Orders
Error Orders
Transferred Rows
```

Technical controls/properties:

```text
CsvFile
File Size
Uploaded Date
```

Final UI decision:

```text
File Name is hidden.
```

Original filename is not returned by the standard Binary Value Action and does not determine parsing success. Successful parsed rows, counts, and Result Message are the operational indicators.

## Main Buttons

### New Batch

Creates a new header with a unique `BatchId`, source system `POS`, and Draft status. A completed batch is not reused for another payload.

### Upload CSV

Final intended sequence:

```text
0  Binary Value Action — Import into CsvFile
10 Collection Save — primary collection
20 Generate Parse event / Call SMK069ImportCsvFileSp
30 Collection Refresh — primary collection
40 Collection Refresh — secondary collection
```

The detail grid should appear immediately after the upload/save/parse sequence.

If a separate Parse button remains in the tenant, keep it as a controlled `Re-parse CSV` fallback.

### Parse CSV / Re-parse CSV

Procedure:

```text
dbo.SMK069ImportCsvFileSp
```

Parameters:

```text
BatchId      = P(BatchId)
RequestedBy  = USERNAME()
ImportedRows = output/event variable
ErrorRows    = output/event variable
Infobar      = output/message variable
```

Direct collection events are preferred:

```text
Collection Save
Call IDO Method
Collection Refresh primary
Collection Refresh secondary
```

Do not rely on `StdFormSave` or `StdFormRefresh` when the direct collection response types are available.

### Import & Validate

Procedure:

```text
dbo.SMK069RunCsvTestBatchSp
```

Final behavior:

```text
CSV detail
→ build canonical JSON
→ dbo.SMK069ReceivePosSalesJsonSp
→ field mapping
→ master-data/default enrichment
→ row/order validation
→ valid orders transferred to temp
→ stop
```

This event must not call `SMK069ReceiveAndProcessPosSalesJsonSp` and must not create `co_mst`, `coitem_mst`, or `co_bln_mst`.

Legacy outputs retained for IDO compatibility:

```text
ProcessedOrders    = 0
ProcessErrorOrders = 0
```

## CSV Parser Rules

Required fields:

```text
custnum
order_date
conum
coline
item
qty_ordered
```

Final tenant/parser requirement:

```text
custnum <= 7
conum   <= 10
item    <= 30
```

The current PR parser source still requires synchronization to the exact final tenant version for these downstream width checks. The sample file already uses compliant values.

Supported aliases are documented in the end-to-end document and in `SMK069ImportCsvFileSp.sql`.

## Status Meanings

### Detail Upload Status

| Value | Meaning |
|---|---|
| `N` | Parsed and ready for Import & Validate |
| `E` | CSV format/basic parser error |
| `S` | Batch Import & Validate completed successfully |

### Batch Status

| Value | Meaning |
|---|---|
| `D` | Draft/parsed and ready |
| `R` | Import & Validate running |
| `E` | Parse/receive/validation error |
| `C` | Receive/validation stage completed |

`C` does not mean a Customer Order already exists.

## Relationship to Error Processing Form

```text
CSV Console primary : ue_SMK069PosCsvBatch
CSV Console detail  : ue_SMK069PosCsvUpload
Error Processing    : ue_SMK069TempSales
```

The forms are connected through the server-side pipeline only.

After a successful Import & Validate:

```text
Temp process_status = V
created_co_num = NULL
```

After Process/Reprocess succeeds:

```text
Temp process_status = P
created_co_num = generated SyteLine CO number
```

## U/M Validation Boundary

U/M validation is performed by `SMK069ReceivePosSalesJsonSp`:

```text
U/M = item base U/M
or
an applicable Global/Item/Customer U/M conversion exists
```

A vendor conversion is not used for Customer Order validation. One invalid U/M line makes the entire source order invalid and prevents transfer to temp.

## Verified and Pending

```text
[VERIFIED] Binary CSV upload stores the BLOB
[VERIFIED] CSV parser creates detail rows
[VERIFIED] Two-row parser test
[IMPLEMENTED IN TENANT] Source system alias normalization to POS
[IMPLEMENTED IN TENANT] Parser downstream length checks
[COMMITTED] Import & Validate only wrapper
[IMPLEMENTED IN TENANT] Receive U/M conversion validation
[DECIDED] File Name hidden
[DECIDED] Upload should immediately parse and refresh detail
[PENDING REPOSITORY SYNC] Exact final parser source
[PENDING EVIDENCE] Formal tenant screenshot/result for auto-parse event chain
[PENDING EVIDENCE] 100-row/25-order full UAT record
```
