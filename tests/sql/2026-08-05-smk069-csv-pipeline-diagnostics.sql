/*
    SMK069 CSV pipeline diagnostics
    Read-only checks for the current test batch.

    Replace @BatchId and @SourceCoNum when testing another batch.
*/

DECLARE
    @BatchId     NVARCHAR(100) = N'CSV-20260805-071048-33489D',
    @SourceCoNum NVARCHAR(30)  = N'POS-TEST-001';

/* 1. CSV header */
SELECT
    batch_id,
    source_system,
    batch_status,
    file_name,
    file_size,
    uploaded_date,
    received_rows,
    total_orders,
    validation_valid_orders,
    validation_error_orders,
    transferred_rows,
    processed_orders,
    process_error_orders,
    result_message,
    started_date,
    completed_date
FROM dbo.ue_SMK069_pos_csv_batch_mst
WHERE batch_id = @BatchId;

/* 2. Parsed CSV rows */
SELECT
    batch_id,
    source_system,
    row_no,
    custnum,
    order_date,
    conum,
    coline,
    item,
    qty_ordered,
    unit_price,
    siteref,
    whse,
    due_date,
    u_m,
    terms_code,
    tax_code1,
    exch_rate,
    upload_status,
    result_message
FROM dbo.ue_SMK069_pos_csv_upload_mst
WHERE batch_id = @BatchId
ORDER BY row_no;

/* 3. Source-system-specific field mapping */
SELECT
    source_system,
    source_field,
    target_field,
    priority_no,
    is_active
FROM dbo.ue_SMK069_pos_field_map_mst
WHERE source_system IN (N'POS', N'POS-CSV-TEST')
ORDER BY source_system, target_field, priority_no;

/* 4. Controlled inbound rows */
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
WHERE batch_id = @BatchId
ORDER BY row_no;

/* 5. Temporary sales staging */
SELECT
    SiteRef,
    order_date,
    co_num,
    co_line,
    cust_num,
    item,
    qty_ordered,
    u_m,
    unit_price,
    whse,
    due_date,
    terms_code,
    tax_code1,
    exch_rate,
    process_status,
    validation_msg,
    error_msg,
    retry_count,
    processed_date,
    processed_by
FROM dbo.ue_SMK069_temp_sales_mst
WHERE LTRIM(RTRIM(co_num)) = @SourceCoNum
ORDER BY SiteRef, co_line;
