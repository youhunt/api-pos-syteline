# 32 — CSV → Blanket CO Form One-Hit FIX2

**Date:** 10 September 2026  
**Workstream:** CSV / POS Inbound → Blanket Customer Order only

## Context

Form: `ue_SMK069PosCsvBatchConsole`

The first one-hit form export attempted to call the existing `SMK069UploadCsv` event from another generated event. In Mongoose Web Client this caused the file-import primary action to fail with:

```text
Error processing 'primaryaction' request:
'<>f__AnonymousType112<string,string,bool,string,string,string,string,string,string,string,string,string>' does not contain a definition for 'choices'
```

The failure occurs before CSV processing. It is a form-event orchestration defect, not a CSV-to-CO stored-procedure defect.

## Root cause

The original working form uses the file picker as a direct primary action:

```text
SMK069UploadCsv Sequence 0
ResponseType 37
ACTION(Import) COMPONENT(btnUploadCsv)
```

The withdrawn one-hit version nested that event:

```text
SMK069CsvToCoOneHit
  -> SMK069UploadCsv
     -> ACTION(Import)
```

That nesting is not safe for the Web Client primary-action contract.

## FIX2 design

The one-hit button itself owns the file import action. It is bound to:

```text
DataSource = object.CsvFile
Binding    = 1
```

Button caption:

```text
Upload CSV to Blanket CO
```

Event generated:

```text
SMK069CsvToCoOneHit
```

Safe event chain:

```text
Sequence 0 | ResponseType 37 | ACTION(Import) COMPONENT(btnCsvToCoOneHit)
Sequence 1 | ResponseType 26 | object DISABLED()
Sequence 2 | ResponseType 21 | SMK069ParseCsv(  )
Sequence 3 | ResponseType 21 | SMK069RunCsvFullProcess(  )
Sequence 4 | ResponseType 28 | object
Sequence 5 | ResponseType 28 | object2
```

This deliberately follows the proven original form pattern: the file picker remains Sequence 0 and is not nested under another event.

## Operator flow

FIX2 does **not** auto-create a batch before opening the file picker. That was removed intentionally because placing database/event work before the primary file-import action is less reliable in the Web Client.

Use:

```text
1. New Batch
2. Upload CSV to Blanket CO
3. Choose CSV
4. Form automatically confirms/parses/imports the CSV
5. SMK069RunCsvTestBatchSp runs
6. CSV continues to Blanket Customer Order processing
```

So the **CSV file → Blanket CO** portion is one button/call chain while batch creation stays explicit and safe.

## Existing manual buttons retained

Keep these for support and retry:

```text
New Batch
Upload CSV
Re-Parse CSV
Process to Blanket CO
```

`Process to Blanket CO` continues to use `SMK069RunCsvTestBatchSp` for an already parsed batch. This remains the correct button for idempotent retry of an existing BatchId such as `CSV-20260909-072038-835E3D`.

## Expected backend path

```text
CSV
→ SMK069ConfirmCsvUploadSp
→ SMK069ImportCsvFileSp
→ SMK069RunCsvTestBatchSp
→ SMK069ReceivePosSalesJsonCoreSp
→ ue_SMK069_temp_sales_mst
→ SMK069ProcessBatchCustomerOrdersSp
→ SMK069ProcessCustomerOrderSp
→ co_mst + coitem_mst + co_bln_mst
```

Success acceptance remains:

```text
co_mst.type = B
coitem_mst contains the CO lines
co_bln_mst contains matching blanket lines
```

## Repository cleanup

The broken full XML export was removed from `main` so it cannot be reused accidentally. The corrected full XML is distributed from the development session as:

```text
ue_SMK069PosCsvBatchConsole_CSV_TO_CO_ONE_HIT_FIX2.XML
```

No database SQL patch is required for this FIX2; this is a Mongoose form-event correction only.
