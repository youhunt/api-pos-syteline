/* =============================================================================
   SMK069 - POS inbound retry history table
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 12 Oct 2026

   Purpose
   - Preserve each failed inbound attempt before a corrected request reuses
     the SAME source_system + batch_id.
   - Keep ue_SMK069_pos_sales_inbound_mst as the current attempt only.
   - Preserve the source row payload/validation fields without guessing tenant
     column lengths: the initial table shape is cloned from inbound_mst.

   Apply Database compatible: ONE BATCH, NO GO.
   Re-runnable: existing history table is left unchanged.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    THROW 521060, N'[SMK069 HISTORY] dbo.ue_SMK069_pos_sales_inbound_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_hist', N'U') IS NULL
BEGIN
    /*
       SELECT INTO intentionally clones the tenant's current inbound data types.
       This avoids drift in fields such as validation_msg / CustPoType between
       older PROD metadata and the verified TRN tenant.
    */
    SELECT TOP (0)
        CAST(i.inbound_id AS BIGINT) AS original_inbound_id,
        i.source_system,
        i.batch_id,
        i.row_no,
        i.raw_json,
        i.SiteRef,
        i.cust_num,
        i.order_date,
        i.co_num,
        i.co_line,
        i.item,
        i.qty_ordered,
        i.unit_price,
        i.whse,
        i.due_date,
        i.u_m,
        i.terms_code,
        i.tax_code1,
        i.exch_rate,
        i.inbound_status,
        i.validation_msg,
        i.received_date,
        i.validated_date,
        i.transferred_date,
        i.created_by,
        i.updated_by,
        i.RowPointer,
        i.cust_po,
        i.is_peak_season,
        CAST(NULL AS INT)           AS attempt_no,
        CAST(NULL AS DATETIME)      AS archived_date,
        CAST(NULL AS NVARCHAR(100)) AS archive_reason
    INTO dbo.ue_SMK069_pos_sales_inbound_hist
    FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i;

    ALTER TABLE dbo.ue_SMK069_pos_sales_inbound_hist
        ADD history_id BIGINT IDENTITY(1,1) NOT NULL;

    ALTER TABLE dbo.ue_SMK069_pos_sales_inbound_hist
        ADD CONSTRAINT PK_SMK069InboundHist
            PRIMARY KEY CLUSTERED (history_id);

    CREATE NONCLUSTERED INDEX IX_SMK069InboundHist_Batch
        ON dbo.ue_SMK069_pos_sales_inbound_hist
        (
            source_system,
            batch_id,
            attempt_no
        );

    CREATE NONCLUSTERED INDEX IX_SMK069InboundHist_CustPo
        ON dbo.ue_SMK069_pos_sales_inbound_hist
        (
            SiteRef,
            cust_po,
            archived_date
        );

    PRINT N'[SMK069 HISTORY] CREATED dbo.ue_SMK069_pos_sales_inbound_hist';
END
ELSE
BEGIN
    PRINT N'[SMK069 HISTORY] EXISTS dbo.ue_SMK069_pos_sales_inbound_hist';
END;

/* Contract checks needed by Core retry/archive logic. */
IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_hist', N'history_id') IS NULL
    THROW 521061, N'[SMK069 HISTORY] history_id tidak tersedia.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_hist', N'original_inbound_id') IS NULL
    THROW 521062, N'[SMK069 HISTORY] original_inbound_id tidak tersedia.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_hist', N'attempt_no') IS NULL
    THROW 521063, N'[SMK069 HISTORY] attempt_no tidak tersedia.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_hist', N'archived_date') IS NULL
    THROW 521064, N'[SMK069 HISTORY] archived_date tidak tersedia.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_hist', N'archive_reason') IS NULL
    THROW 521065, N'[SMK069 HISTORY] archive_reason tidak tersedia.', 1;

PRINT N'[SMK069 HISTORY] SUCCESS - history table contract verified.';
