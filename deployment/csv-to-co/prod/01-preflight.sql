/* =============================================================================
   SMK069 PROD PRE-FLIGHT
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-24
   Mode  : READ-ONLY validation. One executable batch. NO GO.

   Run this AFTER Mongoose/UET/table/view metadata has been migrated to PROD,
   and BEFORE deploying the canonical runtime SQL package.
   ============================================================================= */

SET NOCOUNT ON;

DECLARE @Missing TABLE
(
    seq     INT IDENTITY(1,1) PRIMARY KEY,
    object_name NVARCHAR(256) NOT NULL,
    reason      NVARCHAR(1000) NOT NULL
);

/* --------------------------------------------------------------------------
   Required custom/runtime objects
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    INSERT @Missing VALUES (N'dbo.ue_SMK069_pos_sales_inbound_mst', N'table tidak ditemukan');

IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    INSERT @Missing VALUES (N'dbo.ue_SMK069_temp_sales_mst', N'table tidak ditemukan');

IF OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst', N'U') IS NULL
    INSERT @Missing VALUES (N'dbo.ue_SMK069_pos_field_map_mst', N'field-map table tidak ditemukan');

IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst', N'U') IS NULL
    INSERT @Missing VALUES (N'dbo.ue_SMK069_pos_csv_batch_mst', N'CSV batch table tidak ditemukan');

IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst', N'U') IS NULL
    INSERT @Missing VALUES (N'dbo.ue_SMK069_pos_csv_upload_mst', N'CSV upload detail table tidak ditemukan');

IF OBJECT_ID(N'dbo.SMK030_UomConvQty2') IS NULL
    INSERT @Missing VALUES (N'dbo.SMK030_UomConvQty2', N'quantity conversion function tidak ditemukan');

IF OBJECT_ID(N'dbo.Getumcf') IS NULL
    INSERT @Missing VALUES (N'dbo.Getumcf', N'U/M conversion function tidak ditemukan');

IF OBJECT_ID(N'dbo.SetSiteSp', N'P') IS NULL
    INSERT @Missing VALUES (N'dbo.SetSiteSp', N'standard site context procedure tidak ditemukan');

/* --------------------------------------------------------------------------
   Inbound schema proven from DEV tenant
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NOT NULL
BEGIN
    DECLARE @InboundRequired TABLE (column_name SYSNAME PRIMARY KEY);
    INSERT @InboundRequired(column_name) VALUES
        (N'inbound_id'),(N'source_system'),(N'batch_id'),(N'row_no'),(N'raw_json'),
        (N'SiteRef'),(N'cust_num'),(N'order_date'),(N'co_num'),(N'co_line'),
        (N'item'),(N'qty_ordered'),(N'unit_price'),(N'whse'),(N'due_date'),
        (N'u_m'),(N'terms_code'),(N'tax_code1'),(N'exch_rate'),(N'inbound_status'),
        (N'validation_msg'),(N'received_date'),(N'validated_date'),(N'transferred_date'),
        (N'cust_po'),(N'is_peak_season');

    INSERT @Missing(object_name, reason)
    SELECT
        N'dbo.ue_SMK069_pos_sales_inbound_mst.' + r.column_name,
        N'required inbound column tidak ditemukan'
    FROM @InboundRequired AS r
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst')
          AND c.name = r.column_name
    );
END;

/* --------------------------------------------------------------------------
   Temp staging contract
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NOT NULL
BEGIN
    DECLARE @TempRequired TABLE (column_name SYSNAME PRIMARY KEY);
    INSERT @TempRequired(column_name) VALUES
        (N'SiteRef'),(N'cust_num'),(N'order_date'),(N'terms_code'),(N'co_num'),
        (N'cust_po'),(N'co_line'),(N'unit_price'),(N'tax_code1'),(N'exch_rate'),
        (N'whse'),(N'item'),(N'qty_ordered'),(N'due_date'),(N'u_m'),
        (N'is_peak_season'),(N'process_status'),(N'validation_msg'),(N'error_msg'),
        (N'retry_count'),(N'processed_date'),(N'processed_by'),(N'created_co_num');

    INSERT @Missing(object_name, reason)
    SELECT
        N'dbo.ue_SMK069_temp_sales_mst.' + r.column_name,
        N'required temp column tidak ditemukan'
    FROM @TempRequired AS r
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst')
          AND c.name = r.column_name
    );
END;

/* --------------------------------------------------------------------------
   CSV detail contract
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst', N'U') IS NOT NULL
BEGIN
    DECLARE @CsvRequired TABLE (column_name SYSNAME PRIMARY KEY);
    INSERT @CsvRequired(column_name) VALUES
        (N'SiteRef'),(N'batch_id'),(N'row_no'),(N'custnum'),(N'order_date'),
        (N'cust_po'),(N'whse'),(N'coline'),(N'item'),(N'qty_ordered'),(N'u_m'),
        (N'due_date'),(N'terms_code'),(N'tax_code1'),(N'exch_rate'),
        (N'is_peak_season'),(N'upload_status'),(N'result_message');

    INSERT @Missing(object_name, reason)
    SELECT
        N'dbo.ue_SMK069_pos_csv_upload_mst.' + r.column_name,
        N'required CSV detail column tidak ditemukan'
    FROM @CsvRequired AS r
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst')
          AND c.name = r.column_name
    );
END;

/* --------------------------------------------------------------------------
   Mapping-view contract. If the view already exists, validate it here.
   If it is absent, 02-deploy-canonical-runtime.sql creates the captured
   canonical DEV definition after prerequisite schema/UET checks pass.
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'V') IS NOT NULL
BEGIN
    DECLARE @ViewRequired TABLE (column_name SYSNAME PRIMARY KEY);
    INSERT @ViewRequired(column_name) VALUES
        (N'inbound_id'),(N'source_system'),(N'batch_id'),(N'row_no'),(N'SiteRef'),
        (N'cust_num'),(N'cust_seq'),(N'cust_po'),(N'order_date'),(N'co_num'),
        (N'co_line'),(N'item'),(N'qty_ordered'),(N'unit_price'),(N'whse'),
        (N'due_date'),(N'u_m'),(N'terms_code'),(N'tax_code1'),(N'exch_rate'),
        (N'is_peak_season'),(N'ValidationStatus');

    INSERT @Missing(object_name, reason)
    SELECT
        N'dbo.ue_SMK069_pos_sales_inbound_mapping_view.' + r.column_name,
        N'required mapping-view column tidak ditemukan'
    FROM @ViewRequired AS r
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE c.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')
          AND c.name = r.column_name
    );
END;

/* --------------------------------------------------------------------------
   Peak Season / POS U/M UET on itemcust_mst
   -------------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.itemcust_mst', N'U') IS NULL
    INSERT @Missing VALUES (N'dbo.itemcust_mst', N'standard item-customer table tidak ditemukan');
ELSE
BEGIN
    IF COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_is_peak_season') IS NULL
        INSERT @Missing VALUES
        (
            N'dbo.itemcust_mst.Uf_SMK069_is_peak_season',
            N'UET field belum dimigrasikan (INT, default 0)'
        );

    IF COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_pos_um') IS NULL
        INSERT @Missing VALUES
        (
            N'dbo.itemcust_mst.Uf_SMK069_pos_um',
            N'UET field belum dimigrasikan (UMType / nvarchar(3))'
        );
END;

/* --------------------------------------------------------------------------
   SyteLine target fields used by the canonical processors
   -------------------------------------------------------------------------- */
IF COL_LENGTH(N'dbo.co_mst', N'consolidate') IS NULL
    INSERT @Missing VALUES (N'dbo.co_mst.consolidate', N'column tidak ditemukan');

IF COL_LENGTH(N'dbo.coitem_mst', N'consolidate') IS NULL
    INSERT @Missing VALUES (N'dbo.coitem_mst.consolidate', N'column tidak ditemukan');

IF COL_LENGTH(N'dbo.coitem_mst', N'release_date') IS NULL
    INSERT @Missing VALUES (N'dbo.coitem_mst.release_date', N'column tidak ditemukan');

IF COL_LENGTH(N'dbo.co_bln_mst', N'stat') IS NULL
    INSERT @Missing VALUES (N'dbo.co_bln_mst.stat', N'column tidak ditemukan');

IF COL_LENGTH(N'dbo.co_bln_mst', N'allow_on_pick_list') IS NULL
    INSERT @Missing VALUES (N'dbo.co_bln_mst.allow_on_pick_list', N'column tidak ditemukan');

/* --------------------------------------------------------------------------
   Result
   -------------------------------------------------------------------------- */
IF EXISTS (SELECT 1 FROM @Missing)
BEGIN
    SELECT seq, object_name, reason
    FROM @Missing
    ORDER BY seq;

    DECLARE @MissingText NVARCHAR(1800);
    SELECT @MissingText =
        STUFF
        (
            (
                SELECT N'; ' + object_name
                FROM @Missing
                ORDER BY seq
                FOR XML PATH(N''), TYPE
            ).value(N'.', N'NVARCHAR(MAX)'),
            1, 2, N''
        );

    DECLARE @ThrowMessage NVARCHAR(2048) =
        LEFT
        (
            N'[SMK069 PROD PREFLIGHT] BELUM SIAP. Missing: '
            + COALESCE(@MissingText, N'<unknown>'),
            2048
        );

    THROW 520001, @ThrowMessage, 1;
END;

SELECT
    N'PASS' AS PreflightStatus,
    DB_NAME() AS DatabaseName,
    OBJECT_SCHEMA_NAME(OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view'))
        + N'.'
        + OBJECT_NAME(OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view'))
        AS MappingView,
    (SELECT modify_date
     FROM sys.objects
     WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view'))
        AS MappingViewModifyDate;

PRINT N'[SMK069 PROD PREFLIGHT] PASS - schema/runtime prerequisites tersedia.';
