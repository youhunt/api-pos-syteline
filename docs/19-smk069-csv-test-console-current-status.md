# 19 — SMK069 CSV Test Console Current Status

Updated: 5 August 2026

## Purpose

`SMK POS CSV TEST CONSOLE` is a functional test harness for loading a local CSV file, parsing it into batch-detail rows, and sending those rows through the existing SMK069 sales integration pipeline.

It is not the same form or collection as `SMK API SALES ERROR PROCESSING`.

## Current Tenant Objects

### CSV Console header

```text
Table : dbo.ue_SMK069_pos_csv_batch_mst
IDO   : ue_SMK069PosCsvBatch
```

Important fields:

```text
batch_id
source_system
batch_status
file_name
csv_file
file_size
uploaded_date
received_rows
total_orders
validation_valid_orders
validation_error_orders
transferred_rows
processed_orders
process_error_orders
result_message
started_date
completed_date
```

### CSV Console detail

```text
Table : dbo.ue_SMK069_pos_csv_upload_mst
IDO   : ue_SMK069PosCsvUpload
```

Master-detail relation:

```text
BatchId = FP(BatchId)
```

### Error Processing staging

```text
Table : dbo.ue_SMK069_temp_sales_mst
IDO   : ue_SMK069TempSales
Form  : ue_SMK069APISalesErrorProcessing
```

The Error Processing form does not read the CSV BLOB or CSV detail table directly. It displays records only after the CSV/inbound flow transfers rows into `ue_SMK069_temp_sales_mst`.

## Form Flow

```text
SMK POS CSV TEST CONSOLE
    ↓
ue_SMK069_pos_csv_batch_mst
    ↓ parse CSV
ue_SMK069_pos_csv_upload_mst
    ↓ Run Full Process
JSON / controlled inbound processing
    ↓
ue_SMK069_temp_sales_mst
    ↓
SMK API SALES ERROR PROCESSING
    ↓ validate/process/reprocess
SMK069ProcessCustomerOrderSp
    ↓
co_mst + coitem_mst
```

## Completed in Tenant

```text
[COMPLETED] Master-detail form
[COMPLETED] Primary collection ue_SMK069PosCsvBatch
[COMPLETED] Secondary collection ue_SMK069PosCsvUpload
[COMPLETED] New Batch creates a new Draft header without overwriting old batches
[COMPLETED] Binary column csv_file VARBINARY(MAX)
[COMPLETED] file_size and uploaded_date columns
[COMPLETED] Manual CsvFile Binary IDO property
[COMPLETED] Binary CSV upload component
[COMPLETED] Collection Save before parsing
[COMPLETED] Collection Refresh after parsing
[COMPLETED] SMK069CsvSplitLine helper
[COMPLETED] SMK069ImportCsvFileSp
[COMPLETED] Fix for duplicate internal table-variable PK constraint
[VERIFIED] Two CSV rows parsed and displayed in the detail collection
[AVAILABLE] Run Full Process button
```

Verified CSV parsing result on 5 August 2026:

```text
Row 1 : C000001 / POS-TEST-001 / line 1 / AA00001
Row 2 : C000001 / POS-TEST-001 / line 2 / AA00002
```

## Latest Full-Process Observation

Batch example:

```text
CSV-20260805-071048-33489D
```

Result shown by the form:

```text
Rows received       : 2
Total orders        : 0
Validation passed   : 0
Validation failed   : 0
CO succeeded        : 0
CO process failed   : 0
```

Interpretation:

```text
CSV parsing succeeded.
The controlled inbound entry point received two rows.
The rows did not form a canonical source order for validation/CO processing.
```

The most likely boundary to verify next is source-system-specific field mapping. The CSV console currently displays `POS-CSV-TEST`; existing integration mapping may be configured under another source-system value such as `POS`.

This must be verified from tenant data before changing defaults.

## Required Diagnostic Queries

### 1. Check source-system mapping

```sql
SELECT
    source_system,
    source_field,
    target_field,
    priority_no,
    is_active
FROM dbo.ue_SMK069_pos_field_map_mst
WHERE source_system IN (N'POS', N'POS-CSV-TEST')
ORDER BY source_system, target_field, priority_no;
```

### 2. Check inbound rows for the batch

```sql
SELECT
    inbound_id,
    source_system,
    batch_id,
    row_no,
    raw_json,
    SiteRef,
    cust_num,
    order_date,
    co_num,
    co_line,
    item,
    qty_ordered,
    inbound_status,
    validation_msg
FROM dbo.ue_SMK069_pos_sales_inbound_mst
WHERE batch_id = N'CSV-20260805-071048-33489D'
ORDER BY row_no;
```

### 3. Check staging transfer

```sql
SELECT *
FROM dbo.ue_SMK069_temp_sales_mst
WHERE co_num = N'POS-TEST-001'
ORDER BY co_line;
```

## Next Development Step

Execute the three read-only diagnostics above and determine where the two rows stop:

```text
CSV detail
→ inbound raw JSON
→ canonical inbound columns
→ temp sales staging
```

Do not modify the Customer Order procedure yet. The Cloud single-line, idempotent, and multi-line Customer Order paths have already been proven independently.

## Repository Synchronization Boundary

This repository now contains the confirmed CSV parser and sample template. Exact tenant sources for the following objects must still be exported or copied before they can be treated as repository source of truth:

```text
SMK069InitializeCsvTestBatchSp
SMK069RunCsvTestBatchSp
SMK069ReceiveAndProcessPosSalesJsonSp
SMK069ReceivePosSalesJsonSp
CSV batch/detail table DDL
CSV batch/detail IDO definitions
SMK POS CSV TEST CONSOLE form definition
```
