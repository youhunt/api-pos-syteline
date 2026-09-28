/* =============================================================================
   SMK069 PROD - CREATE CORE PHYSICAL TABLES
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Source: TRN metadata captured 2026-09-28
   Mode  : Apply Database compatible, ONE BATCH, NO GO

   Creates:
   1. dbo.ue_SMK069_pos_sales_inbound_mst
   2. dbo.ue_SMK069_temp_sales_mst
   3. dbo.ue_SMK069_pos_csv_batch_mst
   4. dbo.ue_SMK069_pos_csv_upload_mst
   5. dbo.ue_SMK069_pos_field_map_mst

   Notes:
   - Re-runnable: an existing table is left unchanged.
   - Index/key/FK definitions are based on the TRN metadata capture.
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
   Source: verified TRN rows supplied 2026-09-28

   Environment-specific values:
   - TRN source rows used SiteRef = Default.
   - PROD must use its own active site context.
   - RowPointer values are generated fresh in the target environment.
   ========================================================================== */
DECLARE @SeedSite dbo.SiteType =
    NULLIF(RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)), N'');

IF @SeedSite IS NULL
    THROW 521049, N'[SMK069 TABLES] Active Site CONTEXT_INFO kosong; field-map seed dibatalkan.', 1;

MERGE dbo.ue_SMK069_pos_field_map_mst AS tgt
USING
(
    VALUES
        (N'POS',N'co_line',N'co_line',CAST(1 AS bit),20,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'co_num',N'co_num',CAST(1 AS bit),20,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'coline',N'co_line',CAST(1 AS bit),10,CAST(1 AS bit),N'POS field used in current sample',NEWID(),@SeedSite),
        (N'POS',N'conum',N'co_num',CAST(1 AS bit),10,CAST(1 AS bit),N'POS field used in current sample',NEWID(),@SeedSite),
        (N'POS',N'cust_num',N'cust_num',CAST(1 AS bit),20,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'cust_po',N'cust_po',CAST(0 AS bit),1,CAST(1 AS bit),NULL,NEWID(),@SeedSite),
        (N'POS',N'custnum',N'cust_num',CAST(1 AS bit),10,CAST(1 AS bit),N'POS field used in current sample',NEWID(),@SeedSite),
        (N'POS',N'customer',N'cust_num',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'customer_no',N'cust_num',CAST(1 AS bit),40,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'due_date',N'due_date',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'duedate',N'due_date',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'exch_rate',N'exch_rate',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'exchange_rate',N'exch_rate',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'item',N'item',CAST(1 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'item_code',N'item',CAST(1 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'line_no',N'co_line',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'order_date',N'order_date',CAST(1 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'order_no',N'co_num',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'orderdate',N'order_date',CAST(1 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'price',N'unit_price',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'qty',N'qty_ordered',CAST(1 AS bit),40,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'qty_order',N'qty_ordered',CAST(1 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'qty_ordered',N'qty_ordered',CAST(1 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'quantity',N'qty_ordered',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'site_ref',N'SiteRef',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'siteref',N'SiteRef',CAST(0 AS bit),10,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'sku',N'item',CAST(1 AS bit),30,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'tax_code',N'tax_code1',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'tax_code1',N'tax_code1',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'terms',N'terms_code',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'terms_code',N'terms_code',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'u_m',N'u_m',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'um',N'u_m',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'unit_price',N'unit_price',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite),
        (N'POS',N'warehouse',N'whse',CAST(0 AS bit),20,CAST(1 AS bit),N'Accepted alias',NEWID(),@SeedSite),
        (N'POS',N'whse',N'whse',CAST(0 AS bit),10,CAST(1 AS bit),N'Canonical field name',NEWID(),@SeedSite)
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
      AND SiteRef = @SeedSite
      AND is_active = 1
) < 36
    THROW 521050, N'[SMK069 TABLES] POS field-map seed tidak lengkap.', 1;

PRINT N'[SMK069 TABLES] SEEDED dbo.ue_SMK069_pos_field_map_mst (36 POS rows) untuk active site.';

PRINT N'[SMK069 TABLES] SUCCESS - five core/config physical tables are present.';
