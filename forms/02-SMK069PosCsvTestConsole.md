# SMK069 POS CSV Test Console

## Identity

```text
Display Caption      : SMK POS CSV TEST CONSOLE
Primary Collection   : ue_SMK069PosCsvBatch
Secondary Collection : ue_SMK069PosCsvUpload
Relation              : BatchId = FP(BatchId)
Purpose               : Functional CSV-to-sales integration test harness
```

## Header Controls

```text
Batch Id
Source System
Batch Status
File Name
CsvFile binary upload
File Size (bytes)
Uploaded Date
Result Message
```

## Main Buttons

### New Batch

Creates a new header with a unique `BatchId` and Draft status without modifying the previously selected batch.

### Upload CSV

Uses a binary import action bound to the `CsvFile` property of `ue_SMK069PosCsvBatch`.

### Parse CSV to Rows

Recommended handler sequence:

```text
10 Collection Save    : primary collection
20 Call IDO Method    : SMK069ImportCsvFileSp
30 Collection Refresh : primary collection
40 Collection Refresh : secondary collection
```

Do not generate `StdFormSave` or `StdFormRefresh` for this action. Direct Collection Save and Collection Refresh are used.

Method parameters:

```text
BatchId      = P(BatchId)
RequestedBy  = USERNAME()
ImportedRows = output/event variable
ErrorRows    = output/event variable
Infobar      = output/message variable
```

### Run Full Process

Builds the canonical JSON payload from detail rows and invokes the controlled inbound/validation/temporary-sales/Customer-Order processing flow.

## Confirmed Parse Result

The sample CSV containing two lines was parsed successfully and displayed in the secondary grid.

```text
Line 1 : C000001 / POS-TEST-001 / AA00001 / Qty 2 / Price 25000
Line 2 : C000001 / POS-TEST-001 / AA00002 / Qty 1 / Price 15000
```

## Current Full-Process Boundary

The latest run received two rows but returned zero source orders. CSV upload and parsing are therefore complete; source-system mapping and canonical inbound construction are the next diagnostic boundary.

## Relationship to Error Processing Form

`SMK POS CSV TEST CONSOLE` and `SMK API SALES ERROR PROCESSING` do not share a primary collection.

```text
CSV Console primary : ue_SMK069PosCsvBatch
CSV Console detail  : ue_SMK069PosCsvUpload
Error Processing    : ue_SMK069TempSales
```

The forms are connected only through the server-side pipeline that transfers canonical data into `dbo.ue_SMK069_temp_sales_mst`.
