/* =============================================================================
   SMK069 PROD - CREATE CORE PHYSICAL TABLES
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Source: DEV metadata captured 2026-09-28
   Mode  : Apply Database compatible, ONE BATCH, NO GO

   Creates:
   1. dbo.ue_SMK069_pos_sales_inbound_mst
   2. dbo.ue_SMK069_temp_sales_mst
   3. dbo.ue_SMK069_pos_csv_batch_mst
   4. dbo.ue_SMK069_pos_csv_upload_mst
   5. dbo.ue_SMK069_pos_field_map_mst

   Notes:
   - Re-runnable: an existing table is left unchanged.
   - Index/key/FK definitions are based on the DEV metadata capture.
   - Mongoose user-defined types used by temp/batch tables must already exist
     in the SyteLine database.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* --------------------------------------------------------------------------
   Standard SyteLine UDT guards used by the captured DEV physical schema
   -------------------------------------------------------------------------- */
IF TYPE_ID(N'dbo.UsernameType') IS NULL
    THROW 521001, N'[SMK069 TABLES] dbo.UsernameType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.CurrentDateType') IS NULL
    THROW 521002, N'[SMK069 TABLES] dbo.CurrentDateType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.RowPointerType') IS NULL
    THROW 521003, N'[SMK069 TABLES] dbo.RowPointerType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.FlagNyType') IS NULL
    THROW 521004, N'[SMK069 TABLES] dbo.FlagNyType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.SiteType') IS NULL
    THROW 521005, N'[SMK069 TABLES] dbo.SiteType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.CustNumType') IS NULL
    THROW 521006, N'[SMK069 TABLES] dbo.CustNumType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.DateType') IS NULL
    THROW 521007, N'[SMK069 TABLES] dbo.DateType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.TermsCodeType') IS NULL
    THROW 521008, N'[SMK069 TABLES] dbo.TermsCodeType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.CoNumType') IS NULL
    THROW 521009, N'[SMK069 TABLES] dbo.CoNumType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.CoLineType') IS NULL
    THROW 521010, N'[SMK069 TABLES] dbo.CoLineType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.CostPrcType') IS NULL
    THROW 521011, N'[SMK069 TABLES] dbo.CostPrcType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.TaxCodeType') IS NULL
    THROW 521012, N'[SMK069 TABLES] dbo.TaxCodeType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.ExchRateType') IS NULL
    THROW 521013, N'[SMK069 TABLES] dbo.ExchRateType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.WhseType') IS NULL
    THROW 521014, N'[SMK069 TABLES] dbo.WhseType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.ItemType') IS NULL
    THROW 521015, N'[SMK069 TABLES] dbo.ItemType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.QtyUnitType') IS NULL
    THROW 521016, N'[SMK069 TABLES] dbo.QtyUnitType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.UMType') IS NULL
    THROW 521017, N'[SMK069 TABLES] dbo.UMType tidak ditemukan.', 1;
IF TYPE_ID(N'dbo.CustPoType') IS NULL
    THROW 521018, N'[SMK069 TABLES] dbo.CustPoType tidak ditemukan.', 1;

/* ==========================================================================
   1. POS inbound landing/audit
   ========================================================================== */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_pos_sales_inbound_mst
    (
        inbound_id       BIGINT IDENTITY(1,1) NOT NULL,
        source_system    NVARCHAR(50) NOT NULL
            CONSTRAINT DF_SMK069Inbound_SourceSystem DEFAULT (N'POS'),
        batch_id         NVARCHAR(100) NOT NULL,
        row_no           INT NOT NULL,
        raw_json         NVARCHAR(MAX) NOT NULL,
        SiteRef          NVARCHAR(8) NULL,
        cust_num         NVARCHAR(20) NULL,
        order_date       DATE NULL,
        co_num           NVARCHAR(30) NULL,
        co_line          INT NULL,
        item             NVARCHAR(50) NULL,
        qty_ordered      DECIMAL(18,8) NULL,
        unit_price       DECIMAL(18,8) NULL,
        whse             NVARCHAR(20) NULL,
        due_date         DATE NULL,
        u_m              NVARCHAR(20) NULL,
        terms_code       NVARCHAR(20) NULL,
        tax_code1        NVARCHAR(20) NULL,
        exch_rate        DECIMAL(18,8) NULL,
        inbound_status   NCHAR(1) NOT NULL
            CONSTRAINT DF_SMK069Inbound_Status DEFAULT (N'R'),
        validation_msg   NVARCHAR(1000) NULL,
        received_date    DATETIME NOT NULL
            CONSTRAINT DF_SMK069Inbound_ReceivedDate DEFAULT (GETDATE()),
        validated_date   DATETIME NULL,
        transferred_date DATETIME NULL,
        created_by       NVARCHAR(128) NULL,
        updated_by       NVARCHAR(128) NULL,
        RowPointer       UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT DF_SMK069Inbound_RowPointer DEFAULT (NEWID()),
        cust_po          dbo.CustPoType NULL,
        is_peak_season   INT NOT NULL
            CONSTRAINT DF_SMK069Inbound_PeakSeason DEFAULT ((0)),

        CONSTRAINT PK_SMK069Inbound
            PRIMARY KEY CLUSTERED (inbound_id),

        CONSTRAINT UQ_SMK069Inbound_SourceBatchRow
            UNIQUE NONCLUSTERED (source_system, batch_id, row_no)
    );

    CREATE NONCLUSTERED INDEX IX_SMK069Inbound_BatchStatus
        ON dbo.ue_SMK069_pos_sales_inbound_mst
        (
            source_system,
            batch_id,
            inbound_status
        );

    CREATE NONCLUSTERED INDEX IX_SMK069Inbound_Order
        ON dbo.ue_SMK069_pos_sales_inbound_mst
        (
            SiteRef,
            co_num,
            co_line
        );

    CREATE UNIQUE NONCLUSTERED INDEX UX_SMK069Inbound_RowPointer
        ON dbo.ue_SMK069_pos_sales_inbound_mst(RowPointer);

    PRINT N'[SMK069 TABLES] CREATED dbo.ue_SMK069_pos_sales_inbound_mst';
END
ELSE
    PRINT N'[SMK069 TABLES] EXISTS dbo.ue_SMK069_pos_sales_inbound_mst';

/* ==========================================================================
   2. Temp sales / Error Processing staging
   ========================================================================== */
IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_temp_sales_mst
    (
        CreatedBy        dbo.UsernameType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_CreatedBy DEFAULT (SUSER_SNAME()),
        UpdatedBy        dbo.UsernameType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_UpdatedBy DEFAULT (SUSER_SNAME()),
        CreateDate       dbo.CurrentDateType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_CreateDate DEFAULT (GETDATE()),
        RecordDate       dbo.CurrentDateType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_RecordDate DEFAULT (GETDATE()),
        RowPointer       dbo.RowPointerType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_RowPointer DEFAULT (NEWID()),
        NoteExistsFlag   dbo.FlagNyType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_NoteExistsFlag DEFAULT ((0)),
        InWorkflow       dbo.FlagNyType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_InWorkflow DEFAULT ((0)),
        SiteRef          dbo.SiteType NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_SiteRef
            DEFAULT (RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))),
        cust_num         dbo.CustNumType NULL,
        order_date       dbo.DateType NULL,
        terms_code       dbo.TermsCodeType NULL,
        co_num           dbo.CoNumType NOT NULL,
        co_line          dbo.CoLineType NOT NULL,
        unit_price       dbo.CostPrcType NULL,
        tax_code1        dbo.TaxCodeType NULL,
        exch_rate        dbo.ExchRateType NULL,
        whse             dbo.WhseType NULL,
        item             dbo.ItemType NULL,
        qty_ordered      dbo.QtyUnitType NULL,
        due_date         dbo.DateType NULL,
        u_m              dbo.UMType NULL,
        process_status   NVARCHAR(1) NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_ProcessStatus DEFAULT (N'N'),
        validation_msg   NVARCHAR(1000) NULL,
        error_msg        NVARCHAR(4000) NULL,
        retry_count      INT NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_RetryCount DEFAULT ((0)),
        processed_date   dbo.DateType NULL,
        processed_by     dbo.UsernameType NULL,
        created_co_num   NVARCHAR(10) NULL,
        cust_po          dbo.CustPoType NULL,
        is_peak_season   INT NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_mst_PeakSeason DEFAULT ((0)),

        CONSTRAINT PK_ue_SMK069_temp_sales_mst
            PRIMARY KEY CLUSTERED
            (
                SiteRef,
                co_num,
                co_line
            ),

        CONSTRAINT IX_ue_SMK069_temp_sales_mst_RowPointer
            UNIQUE NONCLUSTERED (RowPointer)
    );

    PRINT N'[SMK069 TABLES] CREATED dbo.ue_SMK069_temp_sales_mst';
END
ELSE
    PRINT N'[SMK069 TABLES] EXISTS dbo.ue_SMK069_temp_sales_mst';

/* ==========================================================================
   3. CSV batch header
   ========================================================================== */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_pos_csv_batch_mst
    (
        batch_id                 NVARCHAR(100) NOT NULL,
        source_system            NVARCHAR(50) NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_SourceSystem DEFAULT (N'POS-CSV-TEST'),
        file_name                NVARCHAR(255) NULL,
        batch_status             NCHAR(1) NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_Status DEFAULT (N'D'),
        received_rows            INT NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_ReceivedRows DEFAULT ((0)),
        total_orders             INT NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_TotalOrders DEFAULT ((0)),
        validation_valid_orders  INT NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_ValidOrders DEFAULT ((0)),
        validation_error_orders  INT NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_ErrorOrders DEFAULT ((0)),
        transferred_rows         INT NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_TransferredRows DEFAULT ((0)),
        processed_orders         INT NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_ProcessedOrders DEFAULT ((0)),
        process_error_orders     INT NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_ProcessErrors DEFAULT ((0)),
        result_message           NVARCHAR(1000) NULL,
        created_date             DATETIME NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_CreatedDate DEFAULT (GETDATE()),
        started_date             DATETIME NULL,
        completed_date           DATETIME NULL,
        RecordDate               DATETIME NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_RecordDate DEFAULT (GETDATE()),
        CreatedBy                NVARCHAR(128) NULL,
        UpdatedBy                NVARCHAR(128) NULL,
        RowPointer               UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_RowPointer DEFAULT (NEWID()),
        csv_file                 VARBINARY(MAX) NULL,
        file_size                INT NULL,
        uploaded_date            DATETIME NULL,
        SiteRef                  dbo.SiteType NOT NULL
            CONSTRAINT DF_SMK069CsvBatch_SiteRef
            DEFAULT (RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))),

        CONSTRAINT PK_SMK069CsvBatch
            PRIMARY KEY CLUSTERED (batch_id)
    );

    CREATE NONCLUSTERED INDEX IX_SMK069CsvBatch_StatusDate
        ON dbo.ue_SMK069_pos_csv_batch_mst
        (
            batch_status,
            created_date
        );

    CREATE UNIQUE NONCLUSTERED INDEX UX_SMK069CsvBatch_RowPointer
        ON dbo.ue_SMK069_pos_csv_batch_mst(RowPointer);

    PRINT N'[SMK069 TABLES] CREATED dbo.ue_SMK069_pos_csv_batch_mst';
END
ELSE
    PRINT N'[SMK069 TABLES] EXISTS dbo.ue_SMK069_pos_csv_batch_mst';

/* ==========================================================================
   4. CSV upload/detail
   ========================================================================== */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_pos_csv_upload_mst
    (
        upload_id        BIGINT IDENTITY(1,1) NOT NULL,
        batch_id         NVARCHAR(100) NOT NULL,
        source_system    NVARCHAR(50) NOT NULL
            CONSTRAINT DF_SMK069CsvUpload_SourceSystem DEFAULT (N'POS-CSV-TEST'),
        file_name        NVARCHAR(255) NULL,
        row_no           INT NOT NULL,
        custnum          NVARCHAR(20) NULL,
        order_date       DATE NULL,
        conum            NVARCHAR(30) NULL,
        coline           INT NULL,
        item             NVARCHAR(50) NULL,
        qty_ordered      DECIMAL(18,8) NULL,
        unit_price       DECIMAL(18,8) NULL,
        siteref          NVARCHAR(8) NULL,
        whse             NVARCHAR(20) NULL,
        due_date         DATE NULL,
        u_m              NVARCHAR(20) NULL,
        terms_code       NVARCHAR(20) NULL,
        tax_code1        NVARCHAR(20) NULL,
        exch_rate        DECIMAL(18,8) NULL,
        upload_status    NCHAR(1) NOT NULL
            CONSTRAINT DF_SMK069CsvUpload_Status DEFAULT (N'N'),
        result_message   NVARCHAR(1000) NULL,
        raw_csv_row      NVARCHAR(MAX) NULL,
        processed_date   DATETIME NULL,
        RecordDate       DATETIME NOT NULL
            CONSTRAINT DF_SMK069CsvUpload_RecordDate DEFAULT (GETDATE()),
        CreatedBy        NVARCHAR(128) NULL,
        UpdatedBy        NVARCHAR(128) NULL,
        RowPointer       UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT DF_SMK069CsvUpload_RowPointer DEFAULT (NEWID()),
        cust_po          dbo.CustPoType NULL,
        is_peak_season   INT NOT NULL
            CONSTRAINT DF_SMK069CsvUpload_PeakSeason DEFAULT ((0)),

        CONSTRAINT PK_SMK069CsvUpload
            PRIMARY KEY CLUSTERED (upload_id),

        CONSTRAINT UQ_SMK069CsvUpload_BatchRow
            UNIQUE NONCLUSTERED (batch_id, row_no),

        CONSTRAINT FK_SMK069CsvUpload_Batch
            FOREIGN KEY (batch_id)
            REFERENCES dbo.ue_SMK069_pos_csv_batch_mst(batch_id)
    );

    CREATE NONCLUSTERED INDEX IX_SMK069CsvUpload_Batch
        ON dbo.ue_SMK069_pos_csv_upload_mst
        (
            batch_id,
            upload_status,
            row_no
        );

    CREATE UNIQUE NONCLUSTERED INDEX UX_SMK069CsvUpload_RowPointer
        ON dbo.ue_SMK069_pos_csv_upload_mst(RowPointer);

    PRINT N'[SMK069 TABLES] CREATED dbo.ue_SMK069_pos_csv_upload_mst';
END
ELSE
    PRINT N'[SMK069 TABLES] EXISTS dbo.ue_SMK069_pos_csv_upload_mst';

/* ==========================================================================
   5. POS external-to-canonical field map
   ========================================================================== */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_pos_field_map_mst
    (
        source_system NVARCHAR(50) NOT NULL,
        source_field  NVARCHAR(100) NOT NULL,
        target_field  NVARCHAR(100) NOT NULL,
        is_required   BIT NOT NULL
            CONSTRAINT DF_SMK069FieldMap_IsRequired DEFAULT ((0)),
        priority_no   INT NOT NULL
            CONSTRAINT DF_SMK069FieldMap_PriorityNo DEFAULT ((100)),
        is_active     BIT NOT NULL
            CONSTRAINT DF_SMK069FieldMap_IsActive DEFAULT ((1)),
        description   NVARCHAR(255) NULL,
        RowPointer    UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT DF_SMK069FieldMap_RowPointer DEFAULT (NEWID()),
        SiteRef       dbo.SiteType NOT NULL
            CONSTRAINT DF_SMK069FieldMap_SiteRef
            DEFAULT (RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))),

        CONSTRAINT PK_SMK069FieldMap
            PRIMARY KEY CLUSTERED (source_system, source_field)
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_SMK069FieldMap_RowPointer
        ON dbo.ue_SMK069_pos_field_map_mst(RowPointer);

    PRINT N'[SMK069 TABLES] CREATED dbo.ue_SMK069_pos_field_map_mst';
END
ELSE
    PRINT N'[SMK069 TABLES] EXISTS dbo.ue_SMK069_pos_field_map_mst';

/* ==========================================================================
   6. Seed POS external-to-canonical field map
   Source: verified DEV rows supplied 2026-09-28
   ========================================================================== */
MERGE dbo.ue_SMK069_pos_field_map_mst AS tgt
USING
(
    VALUES
        (N'POS',N'co_line',N'co_line',CAST(1 AS bit),20,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'3A891D55-D4F9-4B5F-AA10-EC0559254BF0'),N'Default'),
        (N'POS',N'co_num',N'co_num',CAST(1 AS bit),20,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'95008871-B468-4C92-BFA2-C4D34F3EB0CC'),N'Default'),
        (N'POS',N'coline',N'co_line',CAST(1 AS bit),10,CAST(1 AS bit),N'POS field used in current sample',CONVERT(uniqueidentifier,N'6FD43DCD-109A-4A60-A09B-0110E9552E43'),N'Default'),
        (N'POS',N'conum',N'co_num',CAST(1 AS bit),10,CAST(1 AS bit),N'POS field used in current sample',CONVERT(uniqueidentifier,N'E345BF35-2E75-4DD1-A010-9758160E5C54'),N'Default'),
        (N'POS',N'cust_num',N'cust_num',CAST(1 AS bit),20,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'336A03BA-6E84-4A2D-A23B-5C70B6A2CF3F'),N'Default'),
        (N'POS',N'cust_po',N'cust_po',CAST(0 AS bit),1,CAST(1 AS bit),NULL,CONVERT(uniqueidentifier,N'39FADE78-9E3C-4E93-AA91-B00B230A2580'),N'Default'),
        (N'POS',N'custnum',N'cust_num',CAST(1 AS bit),10,CAST(1 AS bit),N'POS field used in current sample',CONVERT(uniqueidentifier,N'85DD83C7-542A-4B7F-BA6A-D63CD2AB1DC5'),N'Default'),
        (N'POS',N'customer',N'cust_num',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'5CAA448A-9673-4A52-9DFF-D5464330C8F6'),N'Default'),
        (N'POS',N'customer_no',N'cust_num',CAST(1 AS bit),40,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'925E2023-04FB-4F69-995B-99492A9B4C3A'),N'Default'),
        (N'POS',N'due_date',N'due_date',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'07402AED-D6E8-4A5F-87DE-3E910A923199'),N'Default'),
        (N'POS',N'duedate',N'due_date',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'7E9C7BF8-6726-4363-8FFC-918F2108F628'),N'Default'),
        (N'POS',N'exch_rate',N'exch_rate',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'49F40D33-F3DE-4647-AC45-6B3339B5B231'),N'Default'),
        (N'POS',N'exchange_rate',N'exch_rate',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'D834E21C-12ED-4ACB-AEC6-67625C3C5AD8'),N'Default'),
        (N'POS',N'item',N'item',CAST(1 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'B3A1433C-CFAC-44D3-831F-45DDC9D4BA25'),N'Default'),
        (N'POS',N'item_code',N'item',CAST(1 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'ED955FFA-ED8A-4EE5-978C-EC79EEF5ED5E'),N'Default'),
        (N'POS',N'line_no',N'co_line',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'3D11575E-496C-4FB2-B8E4-148938C48128'),N'Default'),
        (N'POS',N'order_date',N'order_date',CAST(1 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'9B9A0CAC-58D7-42E2-8A4B-1F4878821D36'),N'Default'),
        (N'POS',N'order_no',N'co_num',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'AD36D314-71B4-4536-8958-3A91262811D2'),N'Default'),
        (N'POS',N'orderdate',N'order_date',CAST(1 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'D1F9B859-0F78-4A64-ABC1-42EACC83BAE9'),N'Default'),
        (N'POS',N'price',N'unit_price',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'90B2D2FF-2D74-4B11-85AA-355AC0AB23E6'),N'Default'),
        (N'POS',N'qty',N'qty_ordered',CAST(1 AS bit),40,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'236782B5-06C0-48BD-900B-47E8FCA51B3E'),N'Default'),
        (N'POS',N'qty_order',N'qty_ordered',CAST(1 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'96BC21D7-E715-42E0-841F-3F6C7F354C19'),N'Default'),
        (N'POS',N'qty_ordered',N'qty_ordered',CAST(1 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'5D78102F-BC07-4393-A00B-430226AEDF03'),N'Default'),
        (N'POS',N'quantity',N'qty_ordered',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'7BC3063B-459E-4B95-8FB0-A7DD3E86A0DC'),N'Default'),
        (N'POS',N'site_ref',N'SiteRef',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'F14D90EF-DF04-4FAE-B5A0-BE70E9DE72CF'),N'Default'),
        (N'POS',N'siteref',N'SiteRef',CAST(0 AS bit),10,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'B4D9F567-589D-4608-910C-585D8D618405'),N'Default'),
        (N'POS',N'sku',N'item',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'EB1A05F1-9DDA-41DA-A2F6-9D68E550B9A0'),N'Default'),
        (N'POS',N'tax_code',N'tax_code1',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'630DECD7-7B37-4303-A78B-2775694B63C0'),N'Default'),
        (N'POS',N'tax_code1',N'tax_code1',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'23CDB89D-80C8-45E4-9C90-5E855FFA1CC9'),N'Default'),
        (N'POS',N'terms',N'terms_code',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'20DE8B7D-D5B9-42E1-B950-A15899A2EA8C'),N'Default'),
        (N'POS',N'terms_code',N'terms_code',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'3492676A-16EC-4F95-BEB1-CAD937900824'),N'Default'),
        (N'POS',N'u_m',N'u_m',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'E93980A7-03FC-4108-8D80-0F1C667F6FD2'),N'Default'),
        (N'POS',N'um',N'u_m',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'6CD01F5D-BF88-4BDB-BA09-284728A4CC6A'),N'Default'),
        (N'POS',N'unit_price',N'unit_price',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'F682915D-32AA-45B4-BEC1-A5CB3FD2D6E7'),N'Default'),
        (N'POS',N'warehouse',N'whse',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',CONVERT(uniqueidentifier,N'FFCE5E52-DAB8-49CB-A32E-4A002D7BAF34'),N'Default'),
        (N'POS',N'whse',N'whse',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',CONVERT(uniqueidentifier,N'8F0F9DBB-CAB8-415E-BB24-F9CA009239F6'),N'Default')
) AS src
(
    source_system,
    source_field,
    target_field,
    is_required,
    priority_no,
    is_active,
    description,
    RowPointer,
    SiteRef
)
ON tgt.source_system = src.source_system
AND tgt.source_field = src.source_field
WHEN MATCHED THEN
    UPDATE SET
        tgt.target_field = src.target_field,
        tgt.is_required  = src.is_required,
        tgt.priority_no  = src.priority_no,
        tgt.is_active    = src.is_active,
        tgt.description  = src.description,
        tgt.SiteRef      = src.SiteRef
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        source_system,
        source_field,
        target_field,
        is_required,
        priority_no,
        is_active,
        description,
        RowPointer,
        SiteRef
    )
    VALUES
    (
        src.source_system,
        src.source_field,
        src.target_field,
        src.is_required,
        src.priority_no,
        src.is_active,
        src.description,
        src.RowPointer,
        src.SiteRef
    );

IF
(
    SELECT COUNT(*)
    FROM dbo.ue_SMK069_pos_field_map_mst
    WHERE source_system = N'POS'
      AND SiteRef = N'Default'
      AND is_active = 1
) < 36
    THROW 521050, N'[SMK069 TABLES] POS field-map seed tidak lengkap.', 1;

PRINT N'[SMK069 TABLES] SEEDED dbo.ue_SMK069_pos_field_map_mst (36 POS rows).';

PRINT N'[SMK069 TABLES] SUCCESS - five core/config physical tables are present.';
