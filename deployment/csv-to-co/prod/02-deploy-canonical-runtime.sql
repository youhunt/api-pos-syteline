/* =============================================================================
   SMK069 PROD CANONICAL RUNTIME DEPLOYMENT
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-24

   IMPORTANT
   ---------
   - Fresh/current-state PROD deployment. This replaces replaying Patch 01..35.
   - Run deployment/CSV-to-CO PROD preflight first.
   - One executable batch. NO GO.
   - Creates/alters the captured final mapping view as part of this runtime.
   - Does NOT create Mongoose UET / IDO / Form metadata.
   - No historical DEV/UAT data backfill is performed.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* Minimum guards. Full checks live in 01-preflight.sql. */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    THROW 520020, N'[PROD-RUNTIME] inbound table belum tersedia. Jalankan preflight.', 1;
IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    THROW 520021, N'[PROD-RUNTIME] temp table belum tersedia. Jalankan preflight.', 1;
IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'is_peak_season') IS NULL
    THROW 520023, N'[PROD-RUNTIME] inbound.is_peak_season belum tersedia.', 1;
IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'cust_po') IS NULL
    THROW 520024, N'[PROD-RUNTIME] temp.cust_po belum tersedia.', 1;
IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'created_co_num') IS NULL
    THROW 520025, N'[PROD-RUNTIME] temp.created_co_num belum tersedia.', 1;
IF COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_is_peak_season') IS NULL
    THROW 520026, N'[PROD-RUNTIME] itemcust UET Peak Season belum tersedia.', 1;
IF OBJECT_ID(N'dbo.SMK030_UomConvQty2') IS NULL
    THROW 520027, N'[PROD-RUNTIME] SMK030_UomConvQty2 belum tersedia.', 1;
IF OBJECT_ID(N'dbo.Getumcf') IS NULL
    THROW 520028, N'[PROD-RUNTIME] Getumcf belum tersedia.', 1;



/* ========================================================================== 
   0. Canonical inbound mapping view dbo.ue_SMK069_pos_sales_inbound_mapping_view
   ========================================================================== */
DECLARE @ProdSql00 NVARCHAR(MAX) = N'';
SET @ProdSql00 = @ProdSql00 + N'CREATE OR ALTER VIEW dbo.ue_SMK069_pos_sales_inbound_mapping_view
AS
SELECT
    i.inbound_id,
    i.source_system,
    i.batch_id,
    i.row_no,
    i.raw_json,
    i.SiteRef,
    c.cust_num,
    c.cust_seq,
    i.cust_po,
    i.order_date,
    i.co_num,
    i.co_line,
    it.item AS item,
    CAST
    (
        ISNULL
        (
            dbo.SMK030_UomConvQty2
            (
                i.qty_ordered,
                ISNULL(dbo.Getumcf(i.u_m, ic.item, '''', ''''), 1),
                ''To Base''
            ),
            0
        ) AS decimal(23,5)
    ) AS qty_ordered,
    (
        SELECT TOP 1 p.cont_price
        FROM itemcustprice p
        JOIN itemcust ci
          ON p.item = ci.item
         AND p.cust_num = ci.cust_num
        WHERE i.order_date >= p.effect_date
          AND ci.cust_item = i.item
          AND ci.u_m = it.u_m
          AND ci.cust_num = c.cust_num
          AND ci.Uf_SMK069_is_peak_season = i.is_peak_season
        ORDER BY p.effect_date DESC
    ) AS unit_price,
    IIF(i.whse = ''P963'', ''PLG'', ''MAIN'') AS whse,
    DATEADD(dd, ISNULL(ic.due_period, 0), i.order_date) AS due_date,
    it.u_m AS u_m,
    cs.terms_code,
    cs.tax_code1,
    i.exch_rate,
    i.inbound_status,
    i.validation_msg,
    i.received_date,
    i.validated_date,
    i.transferred_date,
    i.created_by,
    i.updated_by,
    i.is_peak_season,
    CASE
        WHEN
            CAST
            (
                ISNULL
                (
                    dbo.SMK030_UomConvQty2
                    (
                        i.qty_ordered,
                        ISNULL(dbo.Getumcf(i.u_m, ic.item, '''', ''''), 1),
                        ''To Base''
                    ),
                    0
                ) AS decimal(23,5)
            )
            <>
            FLOOR
            (
                CAST
                (
                    ISNULL
                    (
                        dbo.SMK030_UomConvQty2
                        (
                            i.qty_ordered,
                            ISNULL(dbo.Getumcf(i.u_m, ic.item, '''', ''''), 1),
                            ''To Base''
                        ),
                        0
                    ) AS decimal(23,5)
                )
            )
        THEN ''N''
        ELSE ''V''
    END AS ValidationStatus
FROM ue_SMK069_pos_sales_inbound_mst i
JOIN custaddr c
  ON i.cust_num = LEFT(c.name, 4)
 AND c.cust_num LIKE ''PH%''
 AND c.cust_seq <> 0
LEFT JOIN customer cs
  ON cs.cust_num = c.cust_num
 AND cs.cust_seq = 0
JOIN itemcust ic
  ON ic.cust_item = i.item
 AND ic.cust_num = c.cust_num
 AND ic.Uf_SMK069_is_peak_season = i.is_peak_season
JOIN item it
  ON it.item = ic.item
WHERE i.SiteRef = CAST(CONTEXT_INFO() AS NVARCHAR(8));';
EXEC sys.sp_executesql @ProdSql00;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')
      AND name = N'ValidationStatus'
)
    THROW 520029, N'[PROD-RUNTIME] mapping view berhasil dibuat tetapi ValidationStatus tidak ditemukan.', 1;

/* ========================================================================== 
   1. CSV helper dbo.SMK069CsvSplitLine
   ========================================================================== */
DECLARE @ProdSql01 NVARCHAR(MAX) = N'';
SET @ProdSql01 = @ProdSql01 + N'/* ================================================================
   Helper: split one CSV record while respecting quoted values.
   ================================================================ */
CREATE OR ALTER FUNCTION dbo.SMK069CsvSplitLine
(
    @Line NVARCHAR(MAX)
)
RETURNS @Fields TABLE
(
    field_no    INT NOT NULL,
    field_value NVARCHAR(MAX) NULL
)
AS
BEGIN
    DECLARE
        @Pos       INT = 1,
        @Length    INT = LEN(ISNULL(@Line, N'''') + N''#'') - 1,
        @FieldNo   INT = 1,
        @InQuotes  BIT = 0,
        @Character NCHAR(1),
        @Value     NVARCHAR(MAX) = N'''';

    WHILE @Pos <= @Length
    BEGIN
        SET @Character = SUBSTRING(@Line, @Pos, 1);

        IF @Character = N''"''
        BEGIN
            IF @InQuotes = 1
               AND @Pos < @Length
               AND SUBSTRING(@Line, @Pos + 1, 1) = N''"''
            BEGIN
                SET @Value = @Value + N''"'';
                SET @Pos += 1;
            END
            ELSE
            BEGIN
                SET @InQuotes = CASE WHEN @InQuotes = 1 THEN 0 ELSE 1 END;
            END;
        END
        ELSE IF @Character = N'','' AND @InQuotes = 0
        BEGIN
            INSERT INTO @Fields (field_no, field_value)
            VALUES (@FieldNo, @Value);

            SET @FieldNo += 1;
            SET @Value = N'''';
        END
        ELSE
        BEGIN
            SET @Value = @Value + @Character;
        END;

        SET @Pos += 1;
    END;

    INSERT INTO @Fields (field_no, field_value)
    VALUES (@FieldNo, @Value);

    RETURN;
END;';
EXEC sys.sp_executesql @ProdSql01;

/* ========================================================================== 
   2. CSV parser dbo.SMK069ImportCsvFileSp
   ========================================================================== */
DECLARE @ProdSql02 NVARCHAR(MAX) = N'';
SET @ProdSql02 = @ProdSql02 + N'/* ================================================================
   Main import procedure.
   ================================================================ */
CREATE OR ALTER PROCEDURE dbo.SMK069ImportCsvFileSp
    @BatchId      NVARCHAR(100),
    @RequestedBy  NVARCHAR(128) = NULL,
    @ImportedRows INT OUTPUT,
    @ErrorRows    INT OUTPUT,
    @Infobar      NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'''');
    SET @RequestedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@RequestedBy)), N''''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ImportedRows = 0;
    SET @ErrorRows = 0;
    SET @Infobar = NULL;

    IF @BatchId IS NULL
    BEGIN
        SET @Infobar = N''[POS-012] batch_id wajib diisi.'';
        RETURN 16;
    END;

    DECLARE
        @CsvBytes     VARBINARY(MAX),
        @CsvText      NVARCHAR(MAX),
        @PayloadBytes VARBINARY(MAX),
        @SourceSystem NVARCHAR(50),
        @FileName     NVARCHAR(255),
        @BatchStatus  NCHAR(1),
        @FileSize     INT;

    SELECT
        @CsvBytes = csv_file,
        @SourceSystem = COALESCE
        (
            NULLIF(LTRIM(RTRIM(source_system)), N''''),
            N''POS-CSV-TEST''
        ),
        @FileName = file_name,
        @BatchStatus = batch_status,
        @FileSize = CONVERT(INT, DATALENGTH(csv_file))
    FROM dbo.ue_SMK069_pos_csv_batch_mst
    WHERE batch_id = @BatchId;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = N''[POS-401] Batch CSV tidak ditemukan.'';
        RETURN 16;
    END;

    IF @BatchStatus = N''R''
    BEGIN
        SET @Infobar = N''[POS-401] Batch CSV sedang diproses dan tidak dapat diimpor ulang.'';
        RETURN 16;
    END;

    IF @BatchStatus = N''C''
    BEGIN
        SET @Infobar = N''[POS-401] Batch CSV sudah Completed. Gunakan New Batch untuk upload CSV baru.'';
        RETURN 16;
    END;

    IF @CsvBytes IS NULL OR DATALENGTH(@CsvBytes) = 0
    BEGIN
        SET @Infobar = N''[POS-402] File CSV belum di-upload atau belum disimpan pada batch.'';
        RETURN 16;
    END;

    /*
       Decode common CSV encodings.
       UTF-16 LE is handled explicitly. UTF-8/ANSI is converted through VARCHAR.
       The expected POS test files use ASCII-compatible field values.
    */
    IF SUBSTRING(@CsvBytes, 1, 2) = 0xFFFE
    BEGIN
        SET @PayloadBytes = SUBSTRING(@CsvBytes, 3, DATALENGTH(@CsvBytes) - 2);
        SET @CsvText = CONVERT(NVARCHAR(MAX), @PayloadBytes);
    END
    ELSE
    BEGIN
        SET @PayloadBytes = CASE
            WHEN SUBSTRING(@CsvBytes, 1, 3) = 0xEFBBBF
                THEN SUBSTRING(@CsvBytes, 4, DATALENGTH(@CsvBytes) - 3)
            ELSE @CsvBytes
        END;

        SET @CsvText = CONVERT(NVARCHAR(MAX), CONVERT(VARCHAR(MAX), @PayloadBytes));
    END;

    SET @CsvText = REPLACE(@CsvText, NCHAR(0), N'''');
    SET @CsvText = REPLACE(@CsvText, NCHAR(13) + NCHAR(10), NCHAR(10));
    SET @CsvText = REPLACE(@CsvText, NCHAR(';
SET @ProdSql02 = @ProdSql02 + N'13), NCHAR(10));

    IF NULLIF(LTRIM(RTRIM(REPLACE(@CsvText, NCHAR(10), N''''))), N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-402] Isi CSV kosong.'';
        RETURN 16;
    END;

    DECLARE @Header TABLE
    (
        field_no       INT NOT NULL PRIMARY KEY,
        original_name  NVARCHAR(255) NULL,
        canonical_name NVARCHAR(50) NULL
    );

    DECLARE @ParsedRows TABLE
    (
        row_no         INT NOT NULL,
        custnum        NVARCHAR(20) NULL,
        order_date     DATE NULL,
        cust_po        NVARCHAR(25) NULL,
        conum          NVARCHAR(30) NULL,
        coline         INT NULL,
        item           NVARCHAR(50) NULL,
        qty_ordered    DECIMAL(18,8) NULL,
        unit_price     DECIMAL(18,8) NULL,
        siteref        NVARCHAR(8) NULL,
        whse           NVARCHAR(20) NULL,
        due_date       DATE NULL,
        u_m            NVARCHAR(20) NULL,
        is_peak_season INT NOT NULL,
        terms_code     NVARCHAR(20) NULL,
        tax_code1      NVARCHAR(20) NULL,
        exch_rate      DECIMAL(18,8) NULL,
        upload_status  NCHAR(1) NOT NULL,
        result_message NVARCHAR(1000) NULL,
        raw_csv_row    NVARCHAR(MAX) NULL
    );

    DECLARE @Fields TABLE
    (
        field_no    INT NOT NULL PRIMARY KEY,
        field_value NVARCHAR(MAX) NULL
    );

    /*
       IMPORTANT:
       T-SQL variables are scoped to the procedure/batch, not to BEGIN/END blocks.
       Therefore @Fields and all row-level variables are declared once here and
       explicitly cleared/reset for every CSV data row.
    */
    DECLARE
        @CursorPos      INT = 1,
        @NextLf         INT,
        @PhysicalRow    INT = 0,
        @DataRow        INT = 0,
        @HeaderFound    BIT = 0,
        @Line           NVARCHAR(MAX),
        @RawCustNum     NVARCHAR(MAX),
        @RawOrderDate   NVARCHAR(MAX),
        @RawCustPo      NVARCHAR(MAX),
        @RawCoNum       NVARCHAR(MAX),
        @RawCoLine      NVARCHAR(MAX),
        @RawItem        NVARCHAR(MAX),
        @RawQty         NVARCHAR(MAX),
        @RawUnitPrice   NVARCHAR(MAX),
        @RawSiteRef     NVARCHAR(MAX),
        @RawWhse        NVARCHAR(MAX),
        @RawDueDate     NVARCHAR(MAX),
        @RawUM          NVARCHAR(MAX),
        @RawIsPeakSeason NVARCHAR(MAX),
        @RawTerms       NVARCHAR(MAX),
        @RawTax         NVARCHAR(MAX),
        @RawExchRate    NVARCHAR(MAX),
        @OrderDate      DATE,
        @CoLine         INT,
        @QtyOrdered     DECIMAL(18,8),
        @UnitPrice      DECIMAL(18,8),
        @DueDate        DATE,
        @ExchRate       DECIMAL(18,8),
        @IsPeakSeason   INT,
        @Message        NVARCHAR(1000);

    WHILE @CursorPos <= LEN(@CsvText + N''#'') - 1
    BEGIN
        SET @NextLf = CHARINDEX(NCHAR(10), @CsvText, @CursorPos);

        IF @NextLf = 0
        BEGIN
            SET @Line = SUBSTRING(@CsvText, @CursorPos, LEN(@CsvText + N''#'') - @CursorPos);
            SET @CursorPos = LEN(@CsvText + ';
SET @ProdSql02 = @ProdSql02 + N'N''#'');
        END
        ELSE
        BEGIN
            SET @Line = SUBSTRING(@CsvText, @CursorPos, @NextLf - @CursorPos);
            SET @CursorPos = @NextLf + 1;
        END;

        SET @PhysicalRow += 1;

        IF NULLIF(LTRIM(RTRIM(@Line)), N'''') IS NULL
            CONTINUE;

        IF @HeaderFound = 0
        BEGIN
            INSERT INTO @Header (field_no, original_name, canonical_name)
            SELECT
                s.field_no,
                NULLIF(LTRIM(RTRIM(s.field_value)), N''''),
                CASE
                    WHEN n.normalized IN (N''custnum'', N''cust_num'', N''customer'', N''customer_code'')
                        THEN N''custnum''
                    WHEN n.normalized IN (N''order_date'', N''orderdate'')
                        THEN N''order_date''
                    WHEN n.normalized IN (N''cust_po'', N''custpo'', N''pos_order_no'', N''store_order_no'')
                        THEN N''cust_po''
                    WHEN n.normalized IN (N''conum'', N''co_num'', N''order_no'', N''order_number'')
                        THEN N''conum''
                    WHEN n.normalized IN (N''coline'', N''co_line'', N''line_no'', N''line_number'')
                        THEN N''coline''
                    WHEN n.normalized IN (N''item'', N''item_code'', N''sku'')
                        THEN N''item''
                    WHEN n.normalized IN (N''qty_ordered'', N''qty'', N''quantity'')
                        THEN N''qty_ordered''
                    WHEN n.normalized IN (N''unit_price'', N''unitprice'', N''price'')
                        THEN N''unit_price''
                    WHEN n.normalized IN (N''siteref'', N''site_ref'', N''site'')
                        THEN N''siteref''
                    WHEN n.normalized IN (N''whse'', N''warehouse'')
                        THEN N''whse''
                    WHEN n.normalized IN (N''due_date'', N''duedate'')
                        THEN N''due_date''
                    WHEN n.normalized IN (N''u_m'', N''um'', N''unit_of_measure'')
                        THEN N''u_m''
                    WHEN n.normalized IN (N''is_peak_season'', N''is_peak_seson'', N''peak_season'')
                        THEN N''is_peak_season''
                    WHEN n.normalized IN (N''terms_code'', N''terms'')
                        THEN N''terms_code''
                    WHEN n.normalized IN (N''tax_code1'', N''tax_code'')
                        THEN N''tax_code1''
                    WHEN n.normalized IN (N''exch_rate'', N''exchange_rate'')
                        THEN N''exch_rate''
                    ELSE NULL
                END
            FROM dbo.SMK069CsvSplitLine(@Line) AS s
            CROSS APPLY
            (
                SELECT LOWER
                (
                    REPLACE
                    (
                        REPLACE
                        (
                            REPLACE(LTRIM(RTRIM(s.field_value)), N'' '', N''_''),
                            N''-'', N''_''
                        ),
                        N''.'', N''''
                    )
                ) AS normalized
            ';
SET @ProdSql02 = @ProdSql02 + N') AS n;

            IF EXISTS
            (
                SELECT canonical_name
                FROM @Header
                WHERE canonical_name IS NOT NULL
                GROUP BY canonical_name
                HAVING COUNT(*) > 1
            )
            BEGIN
                SET @Infobar = N''[POS-403] Header CSV memiliki kolom yang duplikat.'';
                RETURN 16;
            END;

            IF EXISTS
            (
                SELECT required_name
                FROM
                (
                    VALUES
                        (N''custnum''),
                        (N''order_date''),
                        (N''cust_po''),
                        (N''whse''),
                        (N''coline''),
                        (N''item''),
                        (N''qty_ordered''),
                        (N''u_m'')
                ) AS required_fields(required_name)
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM @Header AS h
                    WHERE h.canonical_name = required_fields.required_name
                )
            )
            BEGIN
                SET @Infobar =
                    N''[POS-403] Header CSV tidak lengkap. Wajib ada: ''
                    + N''custnum, order_date, cust_po, whse, coline, item, qty_ordered, u_m.'';
                RETURN 16;
            END;

            SET @HeaderFound = 1;
            CONTINUE;
        END;

        SET @DataRow += 1;

        DELETE FROM @Fields;

        SET @RawCustNum = NULL;
        SET @RawOrderDate = NULL;
        SET @RawCustPo = NULL;
        SET @RawCoNum = NULL;
        SET @RawCoLine = NULL;
        SET @RawItem = NULL;
        SET @RawQty = NULL;
        SET @RawUnitPrice = NULL;
        SET @RawSiteRef = NULL;
        SET @RawWhse = NULL;
        SET @RawDueDate = NULL;
        SET @RawUM = NULL;
        SET @RawIsPeakSeason = NULL;
        SET @RawTerms = NULL;
        SET @RawTax = NULL;
        SET @RawExchRate = NULL;
        SET @OrderDate = NULL;
        SET @CoLine = NULL;
        SET @QtyOrdered = NULL;
        SET @UnitPrice = NULL;
        SET @DueDate = NULL;
        SET @ExchRate = NULL;
        SET @IsPeakSeason = 0;
        SET @Message = N'''';

        INSERT INTO @Fields (field_no, field_value)
        SELECT field_no, NULLIF(LTRIM(RTRIM(field_value)), N'''')
        FROM dbo.SMK069CsvSplitLine(@Line);

        SELECT
            @RawCustNum   = MAX(CASE WHEN h.canonical_name = N''custnum''      THEN f.field_value END),
            @RawOrderDate = MAX(CASE WHEN h.canonical_name = N''order_date''   THEN f.field_value END),
            @RawCustPo    = MAX(CASE WHEN h.canonical_name = N''cust_po''      THEN f.field_value END),
            @RawCoNum     = MAX(CASE WHEN h.canonical_name = N''conum''        THEN f.field_value END),
            @RawCoLine    = MAX(CASE WHEN h.canonical_name = N''coline''       THEN f.field_value END),
            @RawItem      = MAX(CASE WHEN h.canonical_name = N''item''      ';
SET @ProdSql02 = @ProdSql02 + N'   THEN f.field_value END),
            @RawQty       = MAX(CASE WHEN h.canonical_name = N''qty_ordered''  THEN f.field_value END),
            @RawUnitPrice = MAX(CASE WHEN h.canonical_name = N''unit_price''   THEN f.field_value END),
            @RawSiteRef   = MAX(CASE WHEN h.canonical_name = N''siteref''      THEN f.field_value END),
            @RawWhse      = MAX(CASE WHEN h.canonical_name = N''whse''         THEN f.field_value END),
            @RawDueDate   = MAX(CASE WHEN h.canonical_name = N''due_date''     THEN f.field_value END),
            @RawUM        = MAX(CASE WHEN h.canonical_name = N''u_m''          THEN f.field_value END),
            @RawIsPeakSeason = MAX(CASE WHEN h.canonical_name = N''is_peak_season'' THEN f.field_value END),
            @RawTerms     = MAX(CASE WHEN h.canonical_name = N''terms_code''   THEN f.field_value END),
            @RawTax       = MAX(CASE WHEN h.canonical_name = N''tax_code1''    THEN f.field_value END),
            @RawExchRate  = MAX(CASE WHEN h.canonical_name = N''exch_rate''    THEN f.field_value END)
        FROM @Header AS h
        LEFT JOIN @Fields AS f
            ON f.field_no = h.field_no;

        SET @OrderDate = COALESCE
        (
            TRY_CONVERT(DATE, @RawOrderDate, 23),
            TRY_CONVERT(DATE, @RawOrderDate, 103),
            TRY_CONVERT(DATE, @RawOrderDate, 101),
            TRY_CONVERT(DATE, @RawOrderDate)
        );

        SET @CoLine = TRY_CONVERT(INT, @RawCoLine);
        SET @QtyOrdered = TRY_CONVERT(DECIMAL(18,8), @RawQty);
        SET @UnitPrice = TRY_CONVERT(DECIMAL(18,8), @RawUnitPrice);
        SET @DueDate = COALESCE
        (
            TRY_CONVERT(DATE, @RawDueDate, 23),
            TRY_CONVERT(DATE, @RawDueDate, 103),
            TRY_CONVERT(DATE, @RawDueDate, 101),
            TRY_CONVERT(DATE, @RawDueDate)
        );
        SET @ExchRate = TRY_CONVERT(DECIMAL(18,8), @RawExchRate);
        SET @IsPeakSeason =
            CASE
                WHEN @RawIsPeakSeason IS NULL THEN 0
                WHEN TRY_CONVERT(INT, @RawIsPeakSeason) = 1 THEN 1
                WHEN TRY_CONVERT(INT, @RawIsPeakSeason) = 0 THEN 0
                ELSE 0
            END;

        IF @RawCustNum IS NULL
            SET @Message += N''[POS-002] custnum kosong; '';
        IF @RawOrderDate IS NULL
            SET @Message += N''[POS-003] order_date kosong; '';
        ELSE IF @OrderDate IS NULL
            SET @Message += N''[POS-003] order_date tidak valid; '';
        IF @RawCustPo IS NULL
            SET @Message += N''[POS-004] cust_po kosong; '';
        IF @RawWhse IS NULL
            SET @Message += N''[POS-005] whse kosong; '';
        IF @RawUM IS NULL
            SET @Message += N''[POS-009] u_m kosong; '';
        IF @RawCoLine IS NULL
            SET @Message += N''[POS-006] coline kosong; '';
        ELSE IF @CoLine IS NULL OR @CoLine <= 0
            SET @Message += N''[POS-006] coline harus bilangan > 0; '';
        IF @RawItem IS NULL
            SET @Message += N''[POS-007] item kosong; '';
  ';
SET @ProdSql02 = @ProdSql02 + N'      IF @RawQty IS NULL
            SET @Message += N''[POS-008] qty_ordered kosong; '';
        ELSE IF @QtyOrdered IS NULL OR @QtyOrdered <= 0
            SET @Message += N''[POS-008] qty_ordered harus angka > 0; '';
        IF @RawDueDate IS NOT NULL AND @DueDate IS NULL
            SET @Message += N''[POS-003] due_date tidak valid; '';
        IF @RawExchRate IS NOT NULL AND (@ExchRate IS NULL OR @ExchRate <= 0)
            SET @Message += N''[POS-010] exch_rate harus angka > 0; '';
        IF @RawIsPeakSeason IS NOT NULL
           AND (TRY_CONVERT(INT, @RawIsPeakSeason) IS NULL OR TRY_CONVERT(INT, @RawIsPeakSeason) NOT IN (0, 1))
            SET @Message += N''[POS-010] is_peak_season harus 0 atau 1; '';

        IF LEN(ISNULL(@RawCustNum, N'''')) > 7
            SET @Message += N''[POS-011] custnum melebihi 7 karakter; '';
        IF LEN(ISNULL(@RawCustPo, N'''')) > 25
            SET @Message += N''[POS-011] cust_po melebihi 25 karakter; '';
        IF LEN(ISNULL(@RawWhse, N'''')) > 8
            SET @Message += N''[POS-011] whse melebihi 8 karakter; '';
        IF LEN(ISNULL(@RawItem, N'''')) > 30
            SET @Message += N''[POS-011] item melebihi 30 karakter; ''

        INSERT INTO @ParsedRows
        (
            row_no,
            custnum,
            order_date,
            cust_po,
            conum,
            coline,
            item,
            qty_ordered,
            unit_price,
            siteref,
            whse,
            due_date,
            u_m,
            is_peak_season,
            terms_code,
            tax_code1,
            exch_rate,
            upload_status,
            result_message,
            raw_csv_row
        )
        VALUES
        (
            @DataRow,
            LEFT(@RawCustNum, 7),
            @OrderDate,
            LEFT(@RawCustPo, 25),
            NULL, /* conum generated later by Receive V2 */
            @CoLine,
            LEFT(@RawItem, 50),
            @QtyOrdered,
            NULL, /* unit_price resolved later by Receive V2 */
            LEFT(@RawSiteRef, 8),
            LEFT(@RawWhse, 20),
            @DueDate,
            LEFT(@RawUM, 20),
            @IsPeakSeason,
            LEFT(@RawTerms, 20),
            LEFT(@RawTax, 20),
            @ExchRate,
            CASE WHEN @Message = N'''' THEN N''N'' ELSE N''E'' END,
            NULLIF(LEFT(@Message, 1000), N''''),
            @Line
        );
    END;

    IF @HeaderFound = 0
    BEGIN
        SET @Infobar = N''[POS-403] Header CSV tidak ditemukan.'';
        RETURN 16;
    END;

    SELECT
        @ImportedRows = COUNT(*),
        @ErrorRows = ISNULL(SUM(CASE WHEN upload_status = N''E'' THEN 1 ELSE 0 END), 0)
    FROM @ParsedRows;

    IF @ImportedRows = 0
    BEGIN
        SET @Infobar = N''[POS-404] CSV tidak memiliki baris data setelah header.'';
        RETURN 16;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE batch_id = @BatchId;

        INSERT INTO dbo.ue_SMK069_pos_csv_upload_';
SET @ProdSql02 = @ProdSql02 + N'mst
        (
            batch_id,
            source_system,
            file_name,
            row_no,
            custnum,
            order_date,
            cust_po,
            conum,
            coline,
            item,
            qty_ordered,
            unit_price,
            siteref,
            whse,
            due_date,
            u_m,
            is_peak_season,
            terms_code,
            tax_code1,
            exch_rate,
            upload_status,
            result_message,
            raw_csv_row,
            processed_date,
            RecordDate,
            CreatedBy,
            UpdatedBy,
            RowPointer
        )
        SELECT
            @BatchId,
            @SourceSystem,
            @FileName,
            p.row_no,
            p.custnum,
            p.order_date,
            p.cust_po,
            p.conum,
            p.coline,
            p.item,
            p.qty_ordered,
            p.unit_price,
            p.siteref,
            p.whse,
            p.due_date,
            p.u_m,
            p.is_peak_season,
            p.terms_code,
            p.tax_code1,
            p.exch_rate,
            p.upload_status,
            p.result_message,
            p.raw_csv_row,
            NULL,
            GETDATE(),
            @RequestedBy,
            @RequestedBy,
            NEWID()
        FROM @ParsedRows AS p;

        /*
            Contract V2.3 persistence synchronization.

            UAT showed the CSV row parser correctly read cust_po from field 3,
            but the physical CSV-detail row could still contain a blank cust_po
            after INSERT.  Synchronize mandatory V2 fields explicitly from the
            parsed in-memory rows before validating persistence.
        */
        UPDATE d
        SET
            d.cust_po = p.cust_po,
            d.whse = p.whse,
            d.u_m = p.u_m,
            d.is_peak_season = p.is_peak_season,
            d.UpdatedBy = @RequestedBy,
            d.RecordDate = GETDATE()
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        INNER JOIN @ParsedRows AS p
          ON p.row_no = d.row_no
        WHERE d.batch_id = @BatchId
          AND
          (
              ISNULL(d.cust_po, N'''') <> ISNULL(p.cust_po, N'''')
              OR ISNULL(d.whse, N'''') <> ISNULL(p.whse, N'''')
              OR ISNULL(d.u_m, N'''') <> ISNULL(p.u_m, N'''')
              OR ISNULL(d.is_peak_season, 0) <> ISNULL(p.is_peak_season, 0)
          );

        /*
            Contract V2.3 persistence guard.
            Do not report successful parsing unless the mandatory V2 fields
            actually survived into ue_SMK069_pos_csv_upload_mst.
        */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_pos_csv_upload_mst
            WHERE batch_id = @BatchId
              AND upload_status = N''N''
              AND
              (
                  NULLIF(LTRIM(RTRIM(cust_po)), N'''') IS NULL
                  OR NULLIF(LTRIM(RTRIM(whse)), N'''') IS ';
SET @ProdSql02 = @ProdSql02 + N'NULL
                  OR NULLIF(LTRIM(RTRIM(u_m)), N'''') IS NULL
              )
        )
        BEGIN
            DECLARE @MissingV2Field NVARCHAR(100);

            SELECT TOP (1)
                @MissingV2Field =
                    CASE
                        WHEN NULLIF(LTRIM(RTRIM(cust_po)), N'''') IS NULL THEN N''cust_po''
                        WHEN NULLIF(LTRIM(RTRIM(whse)), N'''') IS NULL THEN N''whse''
                        WHEN NULLIF(LTRIM(RTRIM(u_m)), N'''') IS NULL THEN N''u_m''
                        ELSE N''unknown''
                    END
            FROM dbo.ue_SMK069_pos_csv_upload_mst
            WHERE batch_id = @BatchId
              AND upload_status = N''N''
              AND
              (
                  NULLIF(LTRIM(RTRIM(cust_po)), N'''') IS NULL
                  OR NULLIF(LTRIM(RTRIM(whse)), N'''') IS NULL
                  OR NULLIF(LTRIM(RTRIM(u_m)), N'''') IS NULL
              )
            ORDER BY row_no;

            DECLARE @PersistenceErrorMessage NVARCHAR(2048);

            SET @PersistenceErrorMessage =
                N''[POS-404] CSV persistence check gagal. Field wajib masih kosong setelah sinkronisasi: ''
                + ISNULL(@MissingV2Field, N''unknown'')
                + N''.'';

            THROW 50140, @PersistenceErrorMessage, 1;
        END;

        SET @Infobar =
            N''[POS-000] CSV V2 berhasil diparsing. Rows=''
            + CONVERT(NVARCHAR(20), @ImportedRows)
            + N'', FormatErrors=''
            + CONVERT(NVARCHAR(20), @ErrorRows)
            + N''.'';

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            file_size = @FileSize,
            uploaded_date = GETDATE(),
            batch_status = CASE WHEN @ErrorRows > 0 THEN N''E'' ELSE N''D'' END,
            received_rows = @ImportedRows,
            total_orders = 0,
            validation_valid_orders = 0,
            validation_error_orders = 0,
            transferred_rows = 0,
            processed_orders = 0,
            process_error_orders = 0,
            result_message = LEFT(@Infobar, 1000),
            started_date = NULL,
            completed_date = NULL,
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        COMMIT TRANSACTION;

        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @Infobar = LEFT
        (
            N''[POS-999] SMK069ImportCsvFileSp gagal ''
            + CONVERT(NVARCHAR(20), ERROR_NUMBER())
            + N'': ''
            + ERROR_MESSAGE(),
            4000
        );

        RETURN 16;
    END CATCH;
END;';
EXEC sys.sp_executesql @ProdSql02;

/* ========================================================================== 
   3. Manual/troubleshooting validation dbo.SMK069ValidateCustomerSp
   ========================================================================== */
DECLARE @ProdSql03 NVARCHAR(MAX) = N'';
SET @ProdSql03 = @ProdSql03 + N'/*
    Object  : dbo.SMK069ValidateCustomerSp
    Purpose : Validate cust_num for one SMK069 staged Customer Order group.
    Scope   : Custom staging validation only. This procedure does not create
              or update standard Customer Order records.

    Tenant naming rule confirmed on 29 July 2026:
        - Stored procedure does not use the ue_ prefix.
        - The custom IDO method receives the ue_ prefix automatically.

    IDO publication target:
        IDO              : ue_SMK069TempSales
        Base Method Name : ValidateCustomer
        Actual Method    : confirm the tenant-generated ue_ name in the wizard
        Method Type      : Stored Procedure - Standard Method
*/

CREATE OR ALTER PROCEDURE dbo.SMK069ValidateCustomerSp
    @SiteRef dbo.SiteType,
    @CoNum   dbo.CoNumType,
    @Infobar dbo.InfobarType OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @InvalidCustNum dbo.CustNumType;

    SET @SiteRef = LTRIM(RTRIM(@SiteRef));
    SET @CoNum   = LTRIM(RTRIM(@CoNum));
    SET @Infobar = NULL;

    IF NULLIF(@SiteRef, N'''') IS NULL
    BEGIN
        SET @Infobar = N''SiteRef wajib diisi.'';
        RETURN 16;
    END;

    IF NULLIF(@CoNum, N'''') IS NULL
    BEGIN
        SET @Infobar = N''CO Number wajib diisi.'';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        WHERE s.SiteRef = @SiteRef
          AND s.co_num = @CoNum
    )
    BEGIN
        SET @Infobar = N''Data staging tidak ditemukan untuk SiteRef ''
                     + RTRIM(@SiteRef)
                     + N'' dan CO Number ''
                     + RTRIM(@CoNum)
                     + N''.'';
        RETURN 16;
    END;

    /*
        Find the first blank or unknown customer in the selected staged CO.
        customer_mst cust_seq = 0 represents the customer master header.
    */
    SELECT TOP (1)
        @InvalidCustNum = NULLIF(LTRIM(RTRIM(s.cust_num)), N'''')
    FROM dbo.ue_SMK069_temp_sales_mst AS s
    WHERE s.SiteRef = @SiteRef
      AND s.co_num = @CoNum
      AND
      (
          NULLIF(LTRIM(RTRIM(s.cust_num)), N'''') IS NULL
          OR NOT EXISTS
          (
              SELECT 1
              FROM dbo.customer_mst AS c
              WHERE c.site_ref = @SiteRef
                AND c.cust_num = s.cust_num
                AND c.cust_seq = 0
          )
      )
    ORDER BY s.co_line;

    IF @@ROWCOUNT > 0
    BEGIN
        SET @Infobar =
            CASE
                WHEN @InvalidCustNum IS NULL
                    THEN N''Customer wajib diisi dan harus terdaftar di customer_mst.''
                ELSE N''Customer '' + RTRIM(@InvalidCustNum)
                   + N'' tidak ditemukan di customer_mst.''
            END;

        UPDATE dbo.ue_SMK069_temp_sales_mst
        SET process_status = N''E'',
            validation_msg = @Infobar
        WHERE SiteRef = @SiteRef
          AND co_num = @CoNum;

        /* Business validation completed; the business result is E';
SET @ProdSql03 = @ProdSql03 + N'rror. */
        RETURN 0;
    END;

    UPDATE dbo.ue_SMK069_temp_sales_mst
    SET process_status = N''V'',
        validation_msg = NULL
    WHERE SiteRef = @SiteRef
      AND co_num = @CoNum;

    RETURN 0;
END;';
EXEC sys.sp_executesql @ProdSql03;

/* ========================================================================== 
   4. Per-order Blanket CO processor dbo.SMK069ProcessCustomerOrderSp
   ========================================================================== */
DECLARE @ProdSql04 NVARCHAR(MAX) = N'';
SET @ProdSql04 = @ProdSql04 + N'/* =============================================================================
   Canonical source: dbo.SMK069ProcessCustomerOrderSp
   -----------------------------------------------------------------------------
   Scope    : CSV / POS inbound -> Blanket Customer Order
   Tenant   : LENSA_SL_CSI_BAK / DEV

   FINAL BUSINESS RULES - 16 Sep 2026
   ----------------------------------
   - cust_po is the canonical business linkage.
   - @SourceCoNum is kept only as a compatibility parameter name. New callers
     pass cust_po; legacy callers may still pass the old transient R... key.
   - New SyteLine CO format = P + YYMMDD + 3-digit daily running.
     Example: P260916001.
   - After success, ue_SMK069_temp_sales_mst.co_num = actual SyteLine CO number.
   - created_co_num stores the same actual CO for Error Processing display.
   - co_mst.type = B and consolidate = 1.
   - coitem_mst.stat = O, consolidate = 1, co_release = 1, release_date = order_date.
   - co_bln_mst is created for every line, stat = O, allow_on_pick_list = 0.
   - Idempotency is customer + business cust_po.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp
    @SiteRef       SiteType,
    @SourceCoNum   NVARCHAR(100), -- compatibility name; pass cust_po for new calls
    @CustSeq       CustSeqType = 0,
    @ProcessedBy   UsernameType = NULL,
    @CreatedCoNum  CoNumType OUTPUT,
    @Success       ListYesNoType OUTPUT,
    @Infobar       InfobarType OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CreatedCoNum = NULL;
    SET @Success = 0;
    SET @Infobar = NULL;

    DECLARE
        @CustNum                   CustNumType,
        @CustPo                    NVARCHAR(100),
        @OrderDate                 DateType,
        @Whse                      WhseType,
        @StageTermsCode            TermsCodeType,
        @StageTaxCode              TaxCodeType,
        @TermsCode                 TermsCodeType,
        @TaxCode                   TaxCodeType,
        @CurrCode                  CurrCodeType,
        @Contact                   ContactType,
        @Phone                     PhoneType,
        @EndUserType               EndUserTypeType,
        @IncludeTaxInPrice         ListYesNoType,
        @HeaderCost                AmountType,
        @HeaderMatlCost            AmountType,
        @HeaderPrice               AmountType,
        @KeyPrefix                 GenericKeyType,
        @KeyID                     BIGINT,
        @NumberLength              INT,
        @MaxKeyID                  BIGINT,
        @LineCount                 INT,
        @ExistingLineCount         INT,
        @ExistingBlanketLineCount  INT,
        @ExistingCoNum             CoNumType,
        @BadItem                   ItemType,
        @LockResult                INT,
        @LockResource              NVARCHAR(255),
        @ErrorMessage              NVARCHAR(4000),
        @ThrowMessage          ';
SET @ProdSql04 = @ProdSql04 + N'    NVARCHAR(2048);

    SET @SiteRef = LTRIM(RTRIM(@SiteRef));
    SET @SourceCoNum = LTRIM(RTRIM(@SourceCoNum));
    SET @ProcessedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ProcessedBy)), N''''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        /* =============================================================
           1. Resolve canonical business key = cust_po
           ============================================================= */
        IF NULLIF(@SiteRef, N'''') IS NULL
            THROW 50001, N''SiteRef wajib diisi.'', 1;

        IF NULLIF(@SourceCoNum, N'''') IS NULL
            THROW 50002, N''Cust PO wajib diisi.'', 1;

        /*
           New callers pass cust_po. Legacy compatibility: an old R... co_num
           can still resolve the same staging order once, then all downstream
           processing uses cust_po only.
        */
        SELECT TOP (1)
            @CustPo = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))
        FROM dbo.ue_SMK069_temp_sales_mst AS t WITH (UPDLOCK, HOLDLOCK)
        WHERE t.SiteRef = @SiteRef
          AND
          (
              LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) = @SourceCoNum
              OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.co_num))) = @SourceCoNum
          )
        ORDER BY
            CASE
                WHEN LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) = @SourceCoNum THEN 0
                ELSE 1
            END,
            t.co_line;

        IF NULLIF(@CustPo, N'''') IS NULL
            THROW 50003, N''Data staging untuk Cust PO tersebut tidak ditemukan.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst WITH (UPDLOCK, HOLDLOCK)
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND process_status = N''C''
        )
            THROW 50004, N''Order staging berstatus Cancelled dan tidak dapat diproses.'', 1;

        SELECT
            @LineCount      = COUNT(*),
            @CustNum        = MIN(LTRIM(RTRIM(cust_num))),
            @OrderDate      = MIN(order_date),
            @Whse           = MIN(LTRIM(RTRIM(whse))),
            @StageTermsCode = MIN(NULLIF(LTRIM(RTRIM(terms_code)), N'''')),
            @StageTaxCode   = MIN(NULLIF(LTRIM(RTRIM(tax_code1)), N''''))
        FROM dbo.ue_SMK069_temp_sales_mst WITH (UPDLOCK, HOLDLOCK)
        WHERE SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;

        IF ISNULL(@LineCount, 0) = 0
            THROW 50005, N''Order staging tidak memiliki line.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND NULLIF(LTRIM(RTRIM(cust_num)), N'''') IS NULL
        )
            THROW 50006, N''cust_num wajib diisi pada seluruh line staging.'', 1;

    ';
SET @ProdSql04 = @ProdSql04 + N'    IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND LTRIM(RTRIM(cust_num)) <> @CustNum
        )
            THROW 50007, N''Satu Cust PO hanya boleh memiliki satu customer.'', 1;

        IF @OrderDate IS NULL
            THROW 50008, N''order_date wajib diisi.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND (order_date IS NULL OR order_date <> @OrderDate)
        )
            THROW 50009, N''Satu Cust PO hanya boleh memiliki satu order_date.'', 1;

        IF NULLIF(@Whse, N'''') IS NULL
            THROW 50010, N''whse wajib diisi.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND
              (
                  NULLIF(LTRIM(RTRIM(whse)), N'''') IS NULL
                  OR LTRIM(RTRIM(whse)) <> @Whse
              )
        )
            THROW 50011, N''Satu Cust PO hanya boleh memiliki satu warehouse.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND NULLIF(LTRIM(RTRIM(item)), N'''') IS NULL
        )
            THROW 50012, N''item wajib diisi pada seluruh line staging.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND ISNULL(qty_ordered, 0) <= 0
        )
            THROW 50013, N''qty_ordered harus lebih besar dari nol.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND ISNULL(unit_price, 0) < 0
        )
            THROW 50014, N''unit_price tidak boleh negatif.'', 1;

        IF @StageTermsCode IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.ue_SMK069_temp_sales_mst
               WHERE SiteRef = @SiteRef
                 AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
                 AND NULLIF(LTRIM(RTRIM(terms_code)), N'''') IS NOT NULL
                 AND LTRIM(RTRIM(terms_code)) <> @StageTermsCode
           )
            THROW 50015, N''Satu Cust PO hanya boleh memiliki satu terms_code.'', 1;

        IF @StageTaxCode IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM dbo.ue_SMK069_temp_sales_mst
 ';
SET @ProdSql04 = @ProdSql04 + N'              WHERE SiteRef = @SiteRef
                 AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
                 AND NULLIF(LTRIM(RTRIM(tax_code1)), N'''') IS NOT NULL
                 AND LTRIM(RTRIM(tax_code1)) <> @StageTaxCode
           )
            THROW 50016, N''Satu Cust PO hanya boleh memiliki satu tax_code1.'', 1;

        /* =============================================================
           2. Validate master data
           ============================================================= */
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.customer_mst
            WHERE site_ref = @SiteRef
              AND LTRIM(RTRIM(cust_num)) = @CustNum
              AND cust_seq = @CustSeq
        )
            THROW 50017, N''Customer/customer sequence tidak ditemukan pada site tersebut.'', 1;

        SELECT
            @Contact           = contact##1,
            @Phone             = phone##1,
            @TermsCode         = terms_code,
            @TaxCode           = tax_code1,
            @EndUserType       = end_user_type,
            @IncludeTaxInPrice = include_tax_in_price
        FROM dbo.customer_mst
        WHERE site_ref = @SiteRef
          AND LTRIM(RTRIM(cust_num)) = @CustNum
          AND cust_seq = @CustSeq;

        SET @TermsCode = COALESCE(@StageTermsCode, @TermsCode);
        SET @TaxCode = COALESCE(@StageTaxCode, @TaxCode);

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.whse_mst
            WHERE site_ref = @SiteRef
              AND LTRIM(RTRIM(whse)) = @Whse
        )
            THROW 50018, N''Warehouse tidak ditemukan pada site tersebut.'', 1;

        SELECT TOP (1)
            @CurrCode = curr_code
        FROM dbo.customer_currency_mst
        WHERE LTRIM(RTRIM(cust_num)) = @CustNum
          AND is_default = 1
        ORDER BY curr_code;

        IF NULLIF(LTRIM(RTRIM(@CurrCode)), N'''') IS NULL
            THROW 50019, N''Default customer currency tidak ditemukan.'', 1;

        SELECT TOP (1)
            @BadItem = s.item
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        LEFT JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
          AND i.item IS NULL;

        IF @BadItem IS NOT NULL
        BEGIN
            SET @ThrowMessage = N''Item tidak ditemukan pada item_mst: ''
                              + LTRIM(RTRIM(@BadItem));
            THROW 50020, @ThrowMessage, 1;
        END;

        SELECT TOP (1)
            @BadItem = s.item
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
          AND NULLIF(LTRIM(RTRIM(COALESCE(s.u_m, i.u_m))), N''''';
SET @ProdSql04 = @ProdSql04 + N') IS NULL;

        IF @BadItem IS NOT NULL
        BEGIN
            SET @ThrowMessage = N''U/M kosong pada staging dan item master untuk item: ''
                              + LTRIM(RTRIM(@BadItem));
            THROW 50021, @ThrowMessage, 1;
        END;

        /* =============================================================
           3. Idempotency: customer + business Cust PO
           ============================================================= */
        SELECT TOP (1)
            @ExistingCoNum = co_num
        FROM dbo.co_mst WITH (UPDLOCK, HOLDLOCK)
        WHERE site_ref = @SiteRef
          AND LTRIM(RTRIM(cust_num)) = @CustNum
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
        ORDER BY RecordDate DESC;

        IF @ExistingCoNum IS NOT NULL
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.co_mst
                WHERE site_ref = @SiteRef
                  AND co_num = @ExistingCoNum
                  AND ISNULL([type], N'''') <> N''B''
            )
                THROW 50031, N''Cust PO sudah memiliki Customer Order tetapi bukan Blanket type B.'', 1;

            SELECT @ExistingLineCount = COUNT(*)
            FROM dbo.coitem_mst
            WHERE site_ref = @SiteRef
              AND co_num = @ExistingCoNum;

            IF ISNULL(@ExistingLineCount, 0) <> @LineCount
            BEGIN
                SET @ThrowMessage = N''Cust PO sudah memiliki Customer Order ''
                                  + LTRIM(RTRIM(@ExistingCoNum))
                                  + N'', tetapi jumlah line tidak sama dengan staging.'';
                THROW 50022, @ThrowMessage, 1;
            END;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_temp_sales_mst AS s
                LEFT JOIN dbo.coitem_mst AS ci
                  ON ci.site_ref = @SiteRef
                 AND ci.co_num = @ExistingCoNum
                 AND ci.co_line = s.co_line
                WHERE s.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
                  AND
                  (
                      ci.co_line IS NULL
                      OR LTRIM(RTRIM(ci.item)) <> LTRIM(RTRIM(s.item))
                      OR ABS(ISNULL(ci.qty_ordered, 0) - ISNULL(s.qty_ordered, 0)) > 0.00000001
                  )
            )
            BEGIN
                SET @ThrowMessage = N''Cust PO sudah memiliki Customer Order ''
                                  + LTRIM(RTRIM(@ExistingCoNum))
                                  + N'', tetapi detail line berbeda dengan staging.'';
                THROW 50023, @ThrowMessage, 1;
            END;

            /* Repair/validate completely missing Blanket lines. */
            SELECT @ExistingBlanketLineCount = COUNT(*)
            FROM dbo.co_bln_mst
            WHERE site_ref = @SiteRef
              AND co_num = @ExistingCoNum;

            IF ISNULL(@ExistingBlanketLineCount, 0';
SET @ProdSql04 = @ProdSql04 + N') = 0
            BEGIN
                INSERT INTO dbo.co_bln_mst
                (
                    site_ref,
                    co_num,
                    co_line,
                    item,
                    blanket_qty,
                    cont_price,
                    stat,
                    u_m,
                    blanket_qty_conv,
                    cont_price_conv,
                    ship_site,
                    description,
                    cost_conv,
                    allow_on_pick_list,
                    whse
                )
                SELECT
                    @SiteRef,
                    @ExistingCoNum,
                    s.co_line,
                    LTRIM(RTRIM(s.item)),
                    s.qty_ordered,
                    s.unit_price,
                    N''O'',
                    COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''''), i.u_m),
                    s.qty_ordered,
                    s.unit_price,
                    @SiteRef,
                    i.description,
                    ISNULL(i.unit_cost, 0),
                    0,
                    @Whse
                FROM dbo.ue_SMK069_temp_sales_mst AS s
                INNER JOIN dbo.item_mst AS i
                  ON i.site_ref = s.SiteRef
                 AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
                WHERE s.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

                IF @@ROWCOUNT <> @LineCount
                    THROW 50032, N''Jumlah Blanket Order line hasil repair tidak sama dengan staging.'', 1;
            END
            ELSE IF @ExistingBlanketLineCount <> @LineCount
                THROW 50033, N''Existing Blanket Order memiliki jumlah blanket line berbeda dengan staging.'', 1;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_temp_sales_mst AS s
                LEFT JOIN dbo.co_bln_mst AS b
                  ON b.site_ref = @SiteRef
                 AND b.co_num = @ExistingCoNum
                 AND b.co_line = s.co_line
                WHERE s.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo
                  AND
                  (
                      b.co_line IS NULL
                      OR LTRIM(RTRIM(b.item)) <> LTRIM(RTRIM(s.item))
                      OR ABS(ISNULL(b.blanket_qty, 0) - ISNULL(s.qty_ordered, 0)) > 0.00000001
                      OR ABS(ISNULL(b.cont_price, 0) - ISNULL(s.unit_price, 0)) > 0.00000001
                      OR ISNULL(b.stat, N'''') <> N''O''
                      OR ISNULL(b.allow_on_pick_list, 1) <> 0
                  )
            )
                THROW 50034, N''Existing Blanket Order detail berbeda dengan staging/target Auto CO.'', 1;

            /* Released flag/date must match the Auto CO business contract. */
            UPDATE ci
            SET
                ci.co_release = 1,
                ci.release_date = c.order_date
            FROM dbo.coitem_mst AS ci
            I';
SET @ProdSql04 = @ProdSql04 + N'NNER JOIN dbo.co_mst AS c
                ON c.site_ref = ci.site_ref
               AND c.co_num = ci.co_num
            WHERE ci.site_ref = @SiteRef
              AND ci.co_num = @ExistingCoNum
              AND
              (
                  ISNULL(ci.co_release, 0) <> 1
                  OR ci.release_date IS NULL
                  OR ci.release_date <> c.order_date
              );

            IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_temp_sales_mst AS x
                WHERE x.SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(100), @ExistingCoNum)))
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.cust_po))) <> @CustPo
            )
                THROW 50036, N''Target SyteLine CO number sudah dipakai row staging lain.'', 1;

            UPDATE dbo.ue_SMK069_temp_sales_mst
            SET
                co_num = @ExistingCoNum,
                created_co_num = @ExistingCoNum,
                process_status = N''P'',
                validation_msg = NULL,
                error_msg = NULL,
                processed_date = GETDATE(),
                processed_by = @ProcessedBy,
                RecordDate = GETDATE(),
                UpdatedBy = @ProcessedBy
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;

            SET @CreatedCoNum = @ExistingCoNum;
            SET @Success = 1;
            SET @Infobar = N''Customer Order ''
                         + LTRIM(RTRIM(@CreatedCoNum))
                         + N'' sudah pernah dibuat untuk Cust PO ''
                         + @CustPo
                         + N''; staging disinkronkan menjadi Processed.'';

            COMMIT TRANSACTION;
            RETURN;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst
            WHERE SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo
              AND process_status = N''P''
        )
            THROW 50024, N''Staging berstatus Processed tetapi Customer Order terkait tidak ditemukan.'', 1;

        /* =============================================================
           4. Calculate totals
           ============================================================= */
        SELECT
            @HeaderMatlCost = SUM(ISNULL(i.matl_cost, 0) * s.qty_ordered),
            @HeaderCost     = SUM(ISNULL(i.unit_cost, 0) * s.qty_ordered),
            @HeaderPrice    = SUM(ISNULL(s.unit_price, 0) * s.qty_ordered)
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

        SET @HeaderMatlCost = ISNULL(@HeaderMatlCost, 0);
        SET @HeaderCost = ISNULL(@HeaderCost, 0);
        SET @HeaderPrice = ISNULL(@HeaderPrice, 0);

        /* =======================================';
SET @ProdSql04 = @ProdSql04 + N'======================
           5. Generate P + YYMMDD + 3-digit daily running
           ============================================================= */
        SET @KeyPrefix = N''P'' + CONVERT(CHAR(6), @OrderDate, 12);
        SET @NumberLength = 3;

        SET @LockResource = N''SMK069_CO_NUM|''
                          + LTRIM(RTRIM(@SiteRef))
                          + N''|''
                          + LTRIM(RTRIM(@KeyPrefix));

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = N''Exclusive'',
            @LockOwner = N''Transaction'',
            @LockTimeout = 15000;

        IF @LockResult < 0
            THROW 50025, N''Gagal memperoleh lock untuk pembuatan nomor Customer Order.'', 1;

        SELECT
            @KeyID = ISNULL
            (
                MAX
                (
                    TRY_CONVERT
                    (
                        BIGINT,
                        SUBSTRING
                        (
                            LTRIM(RTRIM(co_num)),
                            LEN(@KeyPrefix) + 1,
                            @NumberLength
                        )
                    )
                ),
                0
            ) + 1
        FROM dbo.co_mst WITH (UPDLOCK, HOLDLOCK)
        WHERE site_ref = @SiteRef
          AND LTRIM(RTRIM(co_num)) LIKE @KeyPrefix + N''%''
          AND LEN(LTRIM(RTRIM(co_num))) = LEN(@KeyPrefix) + @NumberLength;

        SET @MaxKeyID = CONVERT(BIGINT, POWER(CONVERT(FLOAT, 10), @NumberLength)) - 1;

        IF @KeyID > @MaxKeyID
            THROW 50026, N''Nomor Customer Order untuk tanggal tersebut sudah penuh.'', 1;

        SET @CreatedCoNum = CONVERT
        (
            NVARCHAR(10),
            @KeyPrefix
            + RIGHT
              (
                  REPLICATE(N''0'', @NumberLength)
                  + CONVERT(NVARCHAR(20), @KeyID),
                  @NumberLength
              )
        );

        IF EXISTS
        (
            SELECT 1
            FROM dbo.co_mst
            WHERE site_ref = @SiteRef
              AND co_num = @CreatedCoNum
        )
            THROW 50027, N''Nomor Customer Order yang dihasilkan sudah digunakan.'', 1;

        /* =============================================================
           6. Insert Blanket Customer Order header
           ============================================================= */
        INSERT INTO dbo.co_mst
        (
            co_num,
            cust_num,
            cust_po,
            [type],
            cust_seq,
            whse,
            order_date,
            curr_code,
            site_ref,
            contact,
            phone,
            terms_code,
            tax_code1,
            end_user_type,
            orig_site,
            include_tax_in_price,
            consolidate,
            [cost],
            matl_cost_t,
            price
        )
        VALUES
        (
            @CreatedCoNum,
            @CustNum,
            ';
SET @ProdSql04 = @ProdSql04 + N'@CustPo,
            N''B'',
            @CustSeq,
            @Whse,
            @OrderDate,
            @CurrCode,
            @SiteRef,
            @Contact,
            @Phone,
            @TermsCode,
            @TaxCode,
            @EndUserType,
            @SiteRef,
            @IncludeTaxInPrice,
            1,
            @HeaderCost,
            @HeaderMatlCost,
            @HeaderPrice
        );

        /* =============================================================
           7. Insert CO lines
           ============================================================= */
        INSERT INTO dbo.coitem_mst
        (
            co_num,
            co_line,
            item,
            qty_ordered,
            u_m,
            due_date,
            release_date,
            co_release,
            price,
            site_ref,
            whse,
            qty_ordered_conv,
            cust_seq,
            co_cust_num,
            ship_site,
            co_orig_site,
            description,
            [cost],
            cgs_total,
            price_conv,
            matl_cost,
            cost_conv,
            matl_cost_conv,
            stat,
            consolidate
        )
        SELECT
            @CreatedCoNum,
            s.co_line,
            LTRIM(RTRIM(s.item)),
            s.qty_ordered,
            COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''''), i.u_m),
            COALESCE(s.due_date, @OrderDate),
            @OrderDate,
            1,
            s.unit_price,
            @SiteRef,
            @Whse,
            s.qty_ordered,
            @CustSeq,
            @CustNum,
            @SiteRef,
            @SiteRef,
            i.description,
            ISNULL(i.unit_cost, 0),
            ISNULL(i.unit_cost, 0),
            s.unit_price,
            ISNULL(i.matl_cost, 0),
            ISNULL(i.unit_cost, 0),
            ISNULL(i.matl_cost, 0),
            N''O'',
            1
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

        IF @@ROWCOUNT <> @LineCount
            THROW 50028, N''Jumlah Customer Order line yang dibuat tidak sama dengan staging.'', 1;

        /* =============================================================
           8. Insert Blanket lines
           ============================================================= */
        INSERT INTO dbo.co_bln_mst
        (
            site_ref,
            co_num,
            co_line,
            item,
            blanket_qty,
            cont_price,
            stat,
            u_m,
            blanket_qty_conv,
            cont_price_conv,
            ship_site,
            description,
            cost_conv,
            allow_on_pick_list,
            whse
        )
        SELECT
            @SiteRef,
            @CreatedCoNum,
            s.co_line,
            LTRI';
SET @ProdSql04 = @ProdSql04 + N'M(RTRIM(s.item)),
            s.qty_ordered,
            s.unit_price,
            N''O'',
            COALESCE(NULLIF(LTRIM(RTRIM(s.u_m)), N''''), i.u_m),
            s.qty_ordered,
            s.unit_price,
            @SiteRef,
            i.description,
            ISNULL(i.unit_cost, 0),
            0,
            @Whse
        FROM dbo.ue_SMK069_temp_sales_mst AS s
        INNER JOIN dbo.item_mst AS i
          ON i.site_ref = s.SiteRef
         AND LTRIM(RTRIM(i.item)) = LTRIM(RTRIM(s.item))
        WHERE s.SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo;

        IF @@ROWCOUNT <> @LineCount
            THROW 50035, N''Jumlah Blanket Order line yang dibuat tidak sama dengan staging.'', 1;

        /* =============================================================
           9. Persist actual SyteLine CO into temp and mark Processed
           ============================================================= */
        IF EXISTS
        (
            SELECT 1
            FROM dbo.ue_SMK069_temp_sales_mst AS x
            WHERE x.SiteRef = @SiteRef
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(100), @CreatedCoNum)))
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), x.cust_po))) <> @CustPo
        )
            THROW 50037, N''Generated SyteLine CO number sudah dipakai row staging lain.'', 1;

        UPDATE dbo.ue_SMK069_temp_sales_mst
        SET
            co_num = @CreatedCoNum,
            created_co_num = @CreatedCoNum,
            process_status = N''P'',
            validation_msg = NULL,
            error_msg = NULL,
            processed_date = GETDATE(),
            processed_by = @ProcessedBy,
            RecordDate = GETDATE(),
            UpdatedBy = @ProcessedBy
        WHERE SiteRef = @SiteRef
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;

        COMMIT TRANSACTION;

        SET @Success = 1;
        SET @Infobar = N''Customer Order ''
                     + LTRIM(RTRIM(@CreatedCoNum))
                     + N'' berhasil dibuat untuk Cust PO ''
                     + @CustPo
                     + N''.'';
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = LEFT
        (
            N''Error ''
            + CONVERT(NVARCHAR(20), ERROR_NUMBER())
            + N'' pada line ''
            + CONVERT(NVARCHAR(20), ERROR_LINE())
            + N'': ''
            + ERROR_MESSAGE(),
            4000
        );

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @CreatedCoNum = NULL;
        SET @Success = 0;
        SET @Infobar = CONVERT(NVARCHAR(2800), @ErrorMessage);

        BEGIN TRY
            IF NULLIF(@CustPo, N'''') IS NOT NULL
            BEGIN
                UPDATE dbo.ue_SMK069_temp_sales_mst
                SET
                    process_status = N''E'',
                    error_msg = @ErrorMessage,
                    retry_count = ISNULL(retry_count, 0) + 1,
                    processed_date = N';
SET @ProdSql04 = @ProdSql04 + N'ULL,
                    processed_by = @ProcessedBy,
                    RecordDate = GETDATE(),
                    UpdatedBy = @ProcessedBy
                WHERE SiteRef = @SiteRef
                  AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo;
            END;
        END TRY
        BEGIN CATCH
            SET @Infobar = CONVERT
            (
                NVARCHAR(2800),
                LEFT
                (
                    @ErrorMessage
                    + N'' | Gagal memperbarui status staging: ''
                    + ERROR_MESSAGE(),
                    4000
                )
            );
        END CATCH;
    END CATCH;
END;';
EXEC sys.sp_executesql @ProdSql04;

/* ========================================================================== 
   5. Batch CO processor dbo.SMK069ProcessBatchCustomerOrdersSp
   ========================================================================== */
DECLARE @ProdSql05 NVARCHAR(MAX) = N'';
SET @ProdSql05 = @ProdSql05 + N'/* =============================================================================
   Canonical source: dbo.SMK069ProcessBatchCustomerOrdersSp
   -----------------------------------------------------------------------------
   Purpose : Process every pending Customer Order of one POS/CSV batch.
   Notes   : - Business linkage is cust_po.
             - Source/POS R... co_num is not used as downstream business key.
             - Per-order processing is delegated to SMK069ProcessCustomerOrderSp.
             - Already processed temp orders are skipped.
             - Caller/IDO must NOT be Transactional.
             - POS-302 is returned when a received batch has no resolvable
               business Cust PO mapping.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp
    @SourceSystem     NVARCHAR(50)   = N''POS'',
    @BatchId          NVARCHAR(100),
    @ProcessedBy      UsernameType   = NULL,
    @ProcessedOrders  INT            OUTPUT,
    @ProcessErrors    INT            OUTPUT,
    @SkippedOrders    INT            OUTPUT,
    @FirstErrorCode   NVARCHAR(20)   OUTPUT,
    @ProcessDetail    NVARCHAR(2800) OUTPUT,
    @CreatedCoNums    NVARCHAR(MAX)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @SourceSystem = UPPER(LTRIM(RTRIM(@SourceSystem)));
    SET @BatchId      = NULLIF(LTRIM(RTRIM(@BatchId)), N'''');
    SET @ProcessedBy  = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ProcessedBy)), N''''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ProcessedOrders = 0;
    SET @ProcessErrors   = 0;
    SET @SkippedOrders   = 0;
    SET @FirstErrorCode  = NULL;
    SET @ProcessDetail   = N'''';
    SET @CreatedCoNums   = N'''';

    IF NULLIF(LTRIM(RTRIM(@Site)), N'''') IS NULL
        RETURN 16;

    IF @BatchId IS NULL
        RETURN 16;

    ;WITH BatchOrders AS
    (
        SELECT DISTINCT
            v.SiteRef                                       AS SiteRef,
            LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))) AS cust_po,
            v.cust_seq                                      AS cust_seq
        FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
        WHERE v.SiteRef       = @Site
          AND v.source_system = @SourceSystem
          AND v.batch_id      = @BatchId
          AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))), N'''') IS NOT NULL
    )
    SELECT
        b.SiteRef,
        b.cust_po,
        b.cust_seq,
        CONVERT
        (
            BIT,
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM dbo.ue_SMK069_temp_sales_mst AS t
                    WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                              COLLATE DATABASE_DEFAULT
                          = UPPER(LTRIM(RTRIM(CON';
SET @ProdSql05 = @ProdSql05 + N'VERT(NVARCHAR(16), b.SiteRef))))
                              COLLATE DATABASE_DEFAULT
                      AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))))
                              COLLATE DATABASE_DEFAULT
                          = UPPER(b.cust_po) COLLATE DATABASE_DEFAULT
                      AND t.process_status IN (N''V'', N''E'')
                )
                THEN 1
                ELSE 0
            END
        ) AS is_pending
    INTO #SMK069BatchOrders
    FROM BatchOrders AS b;

    IF NOT EXISTS (SELECT 1 FROM #SMK069BatchOrders)
    BEGIN
        SET @ProcessErrors  = 1;
        SET @FirstErrorCode = N''POS-302'';
        SET @ProcessDetail  = LEFT
        (
            N''[POS-302] Auto CO tidak menemukan business Cust PO untuk batch. ''
            + N''Periksa dbo.ue_SMK069_pos_sales_inbound_mapping_view: SiteRef=''
            + COALESCE(CONVERT(NVARCHAR(16), @Site), N''<NULL>'')
            + N''; SourceSystem='' + COALESCE(@SourceSystem, N''<NULL>'')
            + N''; BatchId='' + COALESCE(@BatchId, N''<NULL>'')
            + N''; pastikan cust_po terisi dan row staging tersedia.'',
            2800
        );
        SET @CreatedCoNums = NULL;
        DROP TABLE #SMK069BatchOrders;
        RETURN 0;
    END;

    SELECT @SkippedOrders = COUNT(*)
    FROM #SMK069BatchOrders
    WHERE is_pending = 0;

    DECLARE
        @SiteRef       SiteType,
        @CustPo        NVARCHAR(100),
        @CustSeq       CustSeqType,
        @CreatedCoNum  CoNumType,
        @Success       ListYesNoType,
        @Info          InfobarType,
        @InfoText      NVARCHAR(4000),
        @CodePos       INT;

    DECLARE OrderCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT SiteRef, cust_po, cust_seq
        FROM #SMK069BatchOrders
        WHERE is_pending = 1
        ORDER BY cust_po;

    OPEN OrderCursor;
    FETCH NEXT FROM OrderCursor INTO @SiteRef, @CustPo, @CustSeq;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @CreatedCoNum = NULL;
        SET @Success      = 0;
        SET @Info         = NULL;

        /*
           @SourceCoNum is retained as the compatibility parameter name of the
           per-order procedure, but the value passed from now on is cust_po.
        */
        EXEC dbo.SMK069ProcessCustomerOrderSp
            @SiteRef      = @SiteRef,
            @SourceCoNum  = @CustPo,
            @CustSeq      = @CustSeq,
            @ProcessedBy  = @ProcessedBy,
            @CreatedCoNum = @CreatedCoNum OUTPUT,
            @Success      = @Success      OUTPUT,
            @Infobar      = @Info         OUTPUT;

        IF ISNULL(@Success, 0) = 1
        BEGIN
            SET @ProcessedOrders += 1;

            IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))), N'''') IS NOT NULL
                SET @CreatedCoNums = LEFT
                (
                    @CreatedCoNums
                    + CASE WHEN NULLIF(@CreatedCoNums, N'''') IS NULL THEN N'''' ELSE N'','' END
                    + LTRIM(RTRIM(CONVERT(NVARCHAR(60),';
SET @ProdSql05 = @ProdSql05 + N' @CreatedCoNum))),
                    8000
                );
        END
        ELSE
        BEGIN
            SET @ProcessErrors += 1;
            SET @InfoText = COALESCE(CONVERT(NVARCHAR(4000), @Info), N'''');

            IF NULLIF(@FirstErrorCode, N'''') IS NULL
            BEGIN
                SET @CodePos = CHARINDEX(N''[POS-'', @InfoText);
                IF @CodePos > 0
                   AND SUBSTRING(@InfoText, @CodePos + 8, 1) = N'']''
                    SET @FirstErrorCode = SUBSTRING(@InfoText, @CodePos + 1, 7);
            END;

            SET @ProcessDetail = LEFT
            (
                @ProcessDetail
                + CASE WHEN NULLIF(@ProcessDetail, N'''') IS NULL THEN N'''' ELSE N'' | '' END
                + N''Cust PO ''
                + COALESCE(@CustPo, N''<NULL>'')
                + N'': ''
                + COALESCE
                  (
                      NULLIF(LEFT(@InfoText, 1000), N''''),
                      N''[POS-301] Process Customer Order gagal.''
                  ),
                2800
            );
        END;

        FETCH NEXT FROM OrderCursor INTO @SiteRef, @CustPo, @CustSeq;
    END;

    CLOSE OrderCursor;
    DEALLOCATE OrderCursor;

    IF @ProcessErrors > 0
        SET @FirstErrorCode = COALESCE(NULLIF(@FirstErrorCode, N''''), N''POS-301'');

    SET @CreatedCoNums = NULLIF(@CreatedCoNums, N'''');
    SET @ProcessDetail = NULLIF(@ProcessDetail, N'''');

    DROP TABLE #SMK069BatchOrders;

    RETURN 0;
END;';
EXEC sys.sp_executesql @ProdSql05;

/* ========================================================================== 
   6. Canonical Receive Core dbo.SMK069ReceivePosSalesJsonCoreSp
   ========================================================================== */
DECLARE @ProdSql06 NVARCHAR(MAX) = N'';
SET @ProdSql06 = @ProdSql06 + N'CREATE OR ALTER PROCEDURE dbo.SMK069ReceivePosSalesJsonCoreSp
    @SourceSystem    NVARCHAR(50) = N''POS'',
    @BatchId         NVARCHAR(100),
    @PayloadJson     NVARCHAR(MAX),
    @ReceivedBy      UsernameType = NULL,
    @ReceivedRows    INT OUTPUT,
    @TotalOrders     INT OUTPUT,
    @ValidOrders     INT OUTPUT,
    @ErrorOrders     INT OUTPUT,
    @TransferredRows INT OUTPUT,
    @Infobar         InfobarType OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    ----------------------------------------------------------------
    -- ACTIVE SITE CONTEXT (SMK069 Site-Aware Hardening 2026-09-03)
    ----------------------------------------------------------------
    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;


    DECLARE
        @InitialTranCount INT = @@TRANCOUNT,
        @SavepointName SYSNAME = N''SMK069ReceiveV240'',
        @ErrorDetail NVARCHAR(2800);

    SET @SourceSystem = UPPER(LTRIM(RTRIM(@SourceSystem)));
    SET @BatchId = LTRIM(RTRIM(@BatchId));

    SET @ReceivedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ReceivedBy)), N''''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ReceivedRows = 0;
    SET @TotalOrders = 0;
    SET @ValidOrders = 0;
    SET @ErrorOrders = 0;
    SET @TransferredRows = 0;
    SET @Infobar = NULL;

    IF NULLIF(LTRIM(RTRIM(@Site)), N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-901] Active Site tidak ditemukan dari CONTEXT_INFO().'';
        RETURN 16;
    END;


    IF NULLIF(@SourceSystem, N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-901] SourceSystem wajib diisi.'';
        RETURN 16;
    END;

    IF NULLIF(@BatchId, N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-012] batch_id wajib diisi.'';
        RETURN 16;
    END;

    IF ISJSON(@PayloadJson) <> 1
       OR LEFT(LTRIM(@PayloadJson), 1) <> N''[''
    BEGIN
        SET @Infobar = N''[POS-001] Payload JSON harus berupa array JSON yang valid.'';
        RETURN 16;
    END;

    /* =============================================================
       Batch idempotency
       ============================================================= */
    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId
    )
    BEGIN
        SELECT
            @ReceivedRows = COUNT(*),
            @TotalOrders = COUNT
            (
                DISTINCT NULLIF(LTRIM(RTRIM(cust_po)), N'''')
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SELECT
            @ValidOrders = COUNT
            (
                DISTINCT CASE
                    WHEN inbound_status = N''T''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            ),
            @ErrorOrders = COUN';
SET @ProdSql06 = @ProdSql06 + N'T
            (
                DISTINCT CASE
                    WHEN inbound_status = N''E''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            ),
            @TransferredRows = ISNULL
            (
                SUM(CASE WHEN inbound_status = N''T'' THEN 1 ELSE 0 END),
                0
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SET @ErrorDetail = NULL;

        SELECT
            @ErrorDetail =
                STUFF
                (
                    (
                        SELECT TOP (10)
                            N'' | ''
                            + CASE
                                  WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'''') IS NULL
                                  THEN N''''
                                  ELSE N''cust_po=''
                                     + LTRIM(RTRIM(e.cust_po))
                                     + N'', ''
                              END
                            + N''coline=''
                            + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                            + N'': ''
                            + CASE
                                WHEN e.validation_msg LIKE N''%mapping view tidak menghasilkan row%''
                                  OR e.validation_msg LIKE N''%inbound_id%''
                                THEN
                                    N''[POS-101] Data payload tidak terdaftar atau tidak sesuai di Infor''
                                    + N'' [custnum=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''''), N''<kosong>'')
                                    + N'', item=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'', u_m=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''''), N''<kosong>'')
                                    + N'', whse=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''Order memiliki line lain%''
                                THEN N''[POS-203] Order ditolak karena terdapat line lain pada cust_po yang tidak valid.''
                                ELSE COALESCE
                                (
                                    NULLIF(LTRIM(RTRIM(e.validation_msg)), N''''),
                                    N''Data payload tidak valid.''
                                )
                              END
                        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                        WHERE e.SiteRef = @Site
                          AND e.source_system = @SourceSystem
              ';
SET @ProdSql06 = @ProdSql06 + N'            AND e.batch_id = @BatchId
                          AND e.inbound_status = N''E''
                        ORDER BY e.row_no
                        FOR XML PATH(N''''), TYPE
                    ).value(N''.'', N''NVARCHAR(MAX)''),
                    1,
                    3,
                    N''''
                );

        SET @Infobar =
            LEFT
            (
                N''[POS-000] Batch '' + @BatchId
                + N'' diterima. Row: '' + CONVERT(NVARCHAR(20), @ReceivedRows)
                + N''; order(cust_po): '' + CONVERT(NVARCHAR(20), @TotalOrders)
                + N''; valid: '' + CONVERT(NVARCHAR(20), @ValidOrders)
                + N''; error: '' + CONVERT(NVARCHAR(20), @ErrorOrders)
                + N''; row masuk temp: '' + CONVERT(NVARCHAR(20), @TransferredRows)
                + N''.''
                + CASE
                      WHEN @ErrorOrders > 0
                       AND NULLIF(@ErrorDetail, N'''') IS NOT NULL
                      THEN N'' ErrorDetail: '' + @ErrorDetail
                      ELSE N''''
                  END,
                4000
            );

        /*
            Idempotent replay returns the SAME business result as the first call.
            Do not add a second "already received/processed" error to the
            business response.
        */
        IF ISNULL(@ErrorOrders, 0) > 0
           OR ISNULL(@ValidOrders, 0) = 0
           OR ISNULL(@TransferredRows, 0) = 0
            RETURN 16;

        RETURN 0;
    END;

    BEGIN TRY
        IF @InitialTranCount = 0
            BEGIN TRANSACTION;
        ELSE
            SAVE TRANSACTION SMK069ReceiveV240;

        /* =============================================================
           1. Preserve raw JSON
           ============================================================= */
        INSERT INTO dbo.ue_SMK069_pos_sales_inbound_mst
        (
            SiteRef,
            source_system,
            batch_id,
            row_no,
            raw_json,
            inbound_status,
            created_by,
            updated_by
        )
        SELECT
            @Site,
            @SourceSystem,
            @BatchId,
            TRY_CONVERT(INT, j.[key]) + 1,
            j.[value],
            N''R'',
            @ReceivedBy,
            @ReceivedBy
        FROM OPENJSON(@PayloadJson) AS j
        WHERE j.[type] = 5;

        SET @ReceivedRows = @@ROWCOUNT;

        IF @ReceivedRows = 0
            THROW 50101, N''[POS-001] Payload tidak memiliki transaksi.'', 1;

        /* =============================================================
           2. Dynamic external-to-canonical raw field extraction
           ============================================================= */
        SELECT
            i.inbound_id,
            m.target_field,
            NULLIF
            (
                LTRIM(RTRIM(CONVERT(NVARCHAR(4000), p.[value]))),
                N''''
            ) AS field_value,
            ROW_NUMBER() OVER
            (
            ';
SET @ProdSql06 = @ProdSql06 + N'    PARTITION BY i.inbound_id, m.target_field
                ORDER BY m.priority_no, p.[key]
            ) AS mapping_rank
        INTO #Mapped
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        CROSS APPLY OPENJSON(i.raw_json) AS p
        INNER JOIN dbo.ue_SMK069_pos_field_map_mst AS m
          ON m.SiteRef = @Site
         AND m.source_system = @SourceSystem
         AND m.source_field =
             LOWER(LTRIM(RTRIM(p.[key] COLLATE DATABASE_DEFAULT)))
         AND m.is_active = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        SELECT
            i.inbound_id,
            MAX(CASE WHEN m.target_field = N''SiteRef''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS SiteRefRaw,
            MAX(CASE WHEN m.target_field = N''cust_num''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS CustNumRaw,
            MAX(CASE WHEN m.target_field = N''order_date''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS OrderDateRaw,
            MAX(CASE WHEN m.target_field = N''cust_po''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS CustPoRaw,
            MAX(CASE WHEN m.target_field = N''co_line''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS CoLineRaw,
            MAX(CASE WHEN m.target_field = N''item''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS ItemRaw,
            MAX(CASE WHEN m.target_field = N''qty_ordered''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS QtyRaw,
            MAX(CASE WHEN m.target_field = N''whse''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS WhseRaw,
            MAX(CASE WHEN m.target_field = N''due_date''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS DueDateRaw,
            MAX(CASE WHEN m.target_field = N''u_m''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS UMRaw,
            MAX(CASE WHEN m.target_field = N''terms_code''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS TermsRaw,
            MAX(CASE WHEN m.target_field = N''tax_code1''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS TaxRaw,
            MAX(CASE WHEN m.target_field = N''exch_rate''
                     AND m.mapping_rank = 1 THEN m.field_value END) AS ExchRateRaw
        INTO #Normalized
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        LEFT JOIN #Mapped AS m
          ON m.inbound_id = i.inbound_id
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
        GROUP BY i.inbound_id;

        IF EXISTS
        (
            SELECT 1
            FROM #Normalized AS n
            WHERE NULLIF(LTRIM(RTRIM(n.SiteRefRaw)), N'''') IS NOT NULL
              AND UPPER(LTRIM(RTRIM(n.SiteRefRaw))) COLLATE DATABASE_DEFAULT
                  <> UPPER(LTRIM(RTRIM(CONVERT(';
SET @ProdSql06 = @ProdSql06 + N'NVARCHAR(16), @Site)))) COLLATE DATABASE_DEFAULT
        )
        BEGIN
            THROW 50109, N''[POS-901] SiteRef payload tidak sesuai dengan Active Site.'', 1;
        END;

        UPDATE i
        SET
            SiteRef = @Site,
            cust_num = LEFT(n.CustNumRaw, 20),
            order_date = TRY_CONVERT(DATE, n.OrderDateRaw),
            cust_po = LEFT(n.CustPoRaw, 25),
            co_num = NULL,
            co_line = TRY_CONVERT(INT, n.CoLineRaw),
            item = LEFT(n.ItemRaw, 50),
            qty_ordered = TRY_CONVERT(DECIMAL(18,8), n.QtyRaw),
            unit_price = NULL,
            whse = LEFT(n.WhseRaw, 20),
            due_date = COALESCE
            (
                TRY_CONVERT(DATE, n.DueDateRaw),
                TRY_CONVERT(DATE, n.OrderDateRaw)
            ),
            u_m = LEFT(n.UMRaw, 20),
            terms_code = LEFT(n.TermsRaw, 20),
            tax_code1 = LEFT(n.TaxRaw, 20),
            exch_rate = COALESCE
            (
                TRY_CONVERT(DECIMAL(18,8), n.ExchRateRaw),
                CONVERT(DECIMAL(18,8), 1)
            ),
            /*
                Peak Season MUST be persisted before #MapView is materialized.
                The canonical mapping view uses inbound.is_peak_season to select
                the correct customer-item/U/M mapping.  Previously the public
                wrapper populated this flag only AFTER Core returned, which
                made Peak payloads map as Normal during Core processing.
            */
            is_peak_season =
                CASE
                    WHEN TRY_CONVERT(INT, JSON_VALUE(i.raw_json, ''$.is_peak_season'')) = 1
                    THEN 1
                    ELSE 0
                END,
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #Normalized AS n
          ON n.inbound_id = i.inbound_id;

        /* =============================================================
           3. Snapshot BUSINESS SOURCE from mapping view
           ============================================================= */
        SELECT
            v.inbound_id,
            v.source_system,
            v.batch_id,
            v.row_no,
            v.SiteRef,
            v.cust_num,
            v.cust_seq,
            v.cust_po,
            v.order_date,
            v.co_num,
            v.co_line,
            v.item,
            v.qty_ordered,
            v.unit_price,
            v.whse,
            v.due_date,
            v.u_m,
            v.terms_code,
            v.tax_code1,
            v.exch_rate,
            COUNT(*) OVER (PARTITION BY v.inbound_id) AS view_row_count,
            ROW_NUMBER() OVER
            (
                PARTITION BY v.inbound_id
                ORDER BY v.cust_num, v.cust_seq, v.item
            ) AS view_rn
        INTO #MapView
        FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
        WHERE v.SiteRef = @Site
          AND v.source_system = @SourceSystem
  ';
SET @ProdSql06 = @ProdSql06 + N'        AND v.batch_id = @BatchId;

        /* =============================================================
           4. Validate mapping-view result
           ============================================================= */
        ;WITH ViewAgg AS
        (
            SELECT
                inbound_id,
                MAX(view_row_count) AS view_row_count,
                MAX(CASE WHEN view_rn = 1 THEN SiteRef END) AS SiteRef,
                MAX(CASE WHEN view_rn = 1 THEN cust_num END) AS cust_num,
                MAX(CASE WHEN view_rn = 1 THEN cust_seq END) AS cust_seq,
                MAX(CASE WHEN view_rn = 1 THEN cust_po END) AS cust_po,
                MAX(CASE WHEN view_rn = 1 THEN order_date END) AS order_date,
                MAX(CASE WHEN view_rn = 1 THEN co_line END) AS co_line,
                MAX(CASE WHEN view_rn = 1 THEN item END) AS item,
                MAX(CASE WHEN view_rn = 1 THEN qty_ordered END) AS qty_ordered,
                MAX(CASE WHEN view_rn = 1 THEN unit_price END) AS unit_price,
                MAX(CASE WHEN view_rn = 1 THEN whse END) AS whse,
                MAX(CASE WHEN view_rn = 1 THEN u_m END) AS u_m,
                MAX(CASE WHEN view_rn = 1 THEN exch_rate END) AS exch_rate
            FROM #MapView
            GROUP BY inbound_id
        )
        UPDATE i
        SET
            validation_msg =
                NULLIF
                (
                    STUFF
                    (
                        CONCAT
                        (
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 0
                                THEN
                                    N''; [POS-101] Data payload tidak terdaftar atau tidak sesuai di Infor''
                                    + N'' [custnum=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), i.cust_num))), N''''), N''<kosong>'')
                                    + N'', item=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'')
                                    + N'', u_m=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.u_m))), N''''), N''<kosong>'')
                                    + N'', whse=''
                                    + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.whse))), N''''), N''<kosong>'')
                                    + N'', coline=''
                                    + COALESCE(CONVERT(NVARCHAR(20), i.co_line), N''<kosong>'')
                                    + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) > 1
                                THEN N''; mapping view menghasilkan lebih dari satu row untuk inbound_id yang sama''
                                ELSE N''''
                            END,
                   ';
SET @ProdSql06 = @ProdSql06 + N'         CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))), N'''') IS NULL
                                THEN N''; [POS-101] Site tidak valid di Infor''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.cust_num))), N'''') IS NULL
                                THEN N''; [POS-102] Store/customer tidak terdaftar di Infor [custnum='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), i.cust_num))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND v.cust_seq IS NULL
                                THEN N''; [POS-107] Store/customer sequence tidak ditemukan di Infor [custnum='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), i.cust_num))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))), N'''') IS NULL
                                THEN N''; [POS-004] cust_po wajib diisi''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND v.order_date IS NULL
                                THEN N''; [POS-003] order_date wajib diisi''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND ISNULL(v.co_line, 0) <= 0
                                THEN N''; [POS-006] coline harus lebih besar dari 0''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.item))), N'''') IS NULL
                                THEN N''; [POS-103] Material tidak terdaftar di Infor [item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND ISNULL(v.qty_ordered, 0) <= 0
                                THEN N''; [POS-008] qty_ordered harus lebih besar dari 0''
                                ELSE N''''
';
SET @ProdSql06 = @ProdSql06 + N'                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND v.unit_price IS NULL
                                THEN N''; [POS-105] Harga material tidak ditemukan di Infor [item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'') + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.u_m))), N''''), N''<kosong>'') + N'', order_date='' + COALESCE(CONVERT(NVARCHAR(10), i.order_date, 23), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), v.whse))), N'''') IS NULL
                                THEN N''; [POS-106] Warehouse tidak valid di Infor [whse='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.whse))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), v.u_m))), N'''') IS NULL
                                THEN N''; [POS-104] U/M tidak valid di Infor [item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.item))), N''''), N''<kosong>'') + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), i.u_m))), N''''), N''<kosong>'') + N'']''
                                ELSE N''''
                            END,
                            CASE
                                WHEN ISNULL(v.view_row_count, 0) = 1
                                 AND ISNULL(v.exch_rate, 0) <= 0
                                THEN N''; [POS-010] exch_rate harus lebih besar dari 0''
                                ELSE N''''
                            END
                        ),
                        1,
                        2,
                        N''''
                    ),
                    N''''
                ),
            inbound_status =
                CASE
                    WHEN ISNULL(v.view_row_count, 0) <> 1
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))), N'''') IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.cust_num))), N'''') IS NULL
                      OR v.cust_seq IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))), N'''') IS NULL
                      OR v.order_date IS NULL
                      OR ISNULL(v.co_line, 0) <= 0
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.item))), N'''') IS NULL
                      OR ISNULL(v.qty_ordered, 0) <= 0
                      OR v.unit_price IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), v.whse))), N'''') IS NULL
                      OR NULLIF(LTRIM(RTRIM(CONVERT(';
SET @ProdSql06 = @ProdSql06 + N'NVARCHAR(80), v.u_m))), N'''') IS NULL
                      OR ISNULL(v.exch_rate, 0) <= 0
                    THEN N''E''
                    ELSE N''V''
                END,
            validated_date = GETDATE(),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        LEFT JOIN ViewAgg AS v
          ON v.inbound_id = i.inbound_id
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           5. Duplicate co_line from mapping view
           ============================================================= */
        ;WITH D AS
        (
            SELECT
                SiteRef,
                cust_po,
                co_line
            FROM #MapView
            WHERE view_rn = 1
              AND view_row_count = 1
            GROUP BY SiteRef, cust_po, co_line
            HAVING COUNT(*) > 1
        )
        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-201] coline duplikat dalam cust_po yang sama''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        INNER JOIN D
          ON D.SiteRef = v.SiteRef
         AND D.cust_po = v.cust_po
         AND D.co_line = v.co_line
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           6. Header consistency from mapping view
           ============================================================= */
        ;WITH H AS
        (
            SELECT
                SiteRef,
                cust_po,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(40), cust_num), N''<NULL>'')) AS cust_count,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(20), cust_seq), N''<NULL>'')) AS seq_count,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(80), whse), N''<NULL>'')) AS whse_count,
                COUNT(DISTINCT ISNULL(CONVERT(NVARCHAR(30), order_date, 126), N''<NULL>'')) AS date_count
            FROM #MapView
            WHERE view_rn = 1
              AND view_row_count = 1
            GROUP BY SiteRef, cust_po
        ),
        BadHeader AS
        (
            SELECT SiteRef, cust_po
            FROM H
            WHERE cust_count > 1
               OR seq_count > 1
               OR whse_count > 1
               OR date_count > 1
        )
        UPDATE i
        SET
            inbound_statu';
SET @ProdSql06 = @ProdSql06 + N's = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-202] Data header tidak konsisten dalam satu cust_po''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        INNER JOIN BadHeader AS b
          ON b.SiteRef = v.SiteRef
         AND b.cust_po = v.cust_po
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           7. Duplicate business order protection - mapped values only
           ============================================================= */
        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-204] cust_po sudah sedang/ pernah diproses''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V''
          AND EXISTS
          (
              SELECT 1
              FROM dbo.ue_SMK069_temp_sales_mst AS t
              WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                        COLLATE DATABASE_DEFAULT
          );

        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg = LEFT
            (
                CONCAT
                (
                    NULLIF(i.validation_msg, N''''),
                    CASE WHEN NULLIF(i.validation_msg, N'''') IS NULL THEN N'''' ELSE N''; '' END,
                    N''[POS-204] cust_po sudah pernah dibuat menjadi Customer Order''
                ),
                1000
            ),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
       ';
SET @ProdSql06 = @ProdSql06 + N' INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V''
          AND EXISTS
          (
              SELECT 1
              FROM dbo.co_mst AS c
              WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), c.site_ref))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_po))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                        COLLATE DATABASE_DEFAULT
                AND c.[type] = N''B''
          );

        /* =============================================================
           8. Atomic order rule
           ============================================================= */
        ;WITH BadRawOrder AS
        (
            SELECT DISTINCT
                i.SiteRef,
                i.cust_po
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.source_system = @SourceSystem
              AND i.batch_id = @BatchId
              AND i.inbound_status = N''E''
              AND NULLIF(LTRIM(RTRIM(i.cust_po)), N'''') IS NOT NULL
        )
        UPDATE i
        SET
            inbound_status = N''E'',
            validation_msg =
                CASE
                    WHEN NULLIF(i.validation_msg, N'''') IS NULL
                    THEN N''[POS-203] Order ditolak karena terdapat line lain yang tidak valid.''
                    ELSE i.validation_msg
                END,
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN BadRawOrder AS b
          ON b.SiteRef = i.SiteRef
         AND b.cust_po = i.cust_po
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId;

        /* =============================================================
           9. Generate co_num per valid mapped SiteRef + cust_po
           ============================================================= */
        CREATE TABLE #GeneratedOrders
        (
            SiteRef NVARCHAR(16) NOT NULL,
            cust_po NVARCHAR(100) NOT NULL,
            order_date DATE NOT NULL,
            co_num NVARCHAR(30) NOT NULL,
            PRIMARY KEY (SiteRef, cust_po)
        );

        DECLARE
            @OrderSiteRef NVARCHAR(16),
            @OrderCustPo NVARCHAR(100),
            @OrderDate DATE,
            @OrderPrefix NVARCHAR(10) = N''R'',
            @Prefix NVARCHAR(20),
            @NewCoNum NVARCHAR(30),
            @NextNo INT,
            @MaxNo INT,
            @LockResult INT,
            @LockResource NVARCHAR(255);

        DECLARE Va';
SET @ProdSql06 = @ProdSql06 + N'lidOrderCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            v.SiteRef,
            v.cust_po,
            MIN(v.order_date)
        FROM #MapView AS v
        INNER JOIN dbo.ue_SMK069_pos_sales_inbound_mst AS i
          ON i.inbound_id = v.inbound_id
        WHERE v.view_rn = 1
          AND v.view_row_count = 1
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V''
        GROUP BY v.SiteRef, v.cust_po;

        OPEN ValidOrderCursor;

        FETCH NEXT FROM ValidOrderCursor
        INTO @OrderSiteRef, @OrderCustPo, @OrderDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Prefix = @OrderPrefix + CONVERT(CHAR(4), @OrderDate, 12);
            SET @LockResource =
                N''SMK069_CONUM|''
                + LTRIM(RTRIM(@OrderSiteRef))
                + N''|''
                + @Prefix;

            EXEC @LockResult = sys.sp_getapplock
                @Resource = @LockResource,
                @LockMode = N''Exclusive'',
                @LockOwner = N''Transaction'',
                @LockTimeout = 15000;

            IF @LockResult < 0
                THROW 50120, N''[POS-901] Gagal memperoleh nomor Customer Order.'', 1;

            SELECT
                @MaxNo = ISNULL(MAX(x.run_no), 0)
            FROM
            (
                SELECT TRY_CONVERT(INT, RIGHT(LTRIM(RTRIM(c.co_num)), 5)) AS run_no
                FROM dbo.co_mst AS c
                WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), c.site_ref))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                        COLLATE DATABASE_DEFAULT
                  AND LTRIM(RTRIM(c.co_num)) LIKE @Prefix + N''%''
                  AND LEN(LTRIM(RTRIM(c.co_num))) = LEN(@Prefix) + 5

                UNION ALL

                SELECT TRY_CONVERT(INT, RIGHT(LTRIM(RTRIM(t.co_num)), 5))
                FROM dbo.ue_SMK069_temp_sales_mst AS t
                WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                        COLLATE DATABASE_DEFAULT
                  AND LTRIM(RTRIM(t.co_num)) LIKE @Prefix + N''%''
                  AND LEN(LTRIM(RTRIM(t.co_num))) = LEN(@Prefix) + 5

                UNION ALL

                SELECT TRY_CONVERT(INT, RIGHT(g.co_num, 5))
                FROM #GeneratedOrders AS g
                WHERE UPPER(LTRIM(RTRIM(g.SiteRef)))
                        COLLATE DATABASE_DEFAULT
                    = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                        COLLATE DATABASE_DEFAULT
                  AND g.co_num LIKE @Prefix + N''%''
            ) AS x
            WHERE x.run_no IS NOT NULL;

            SET @NextNo = ISNULL(@MaxNo, 0) + 1;

            IF @NextNo > 99999
                THROW 50121, N''[POS-901] Running number Customer Order untuk periode tersebut sudah penuh.'', 1;

            S';
SET @ProdSql06 = @ProdSql06 + N'ET @NewCoNum =
                @Prefix
                + RIGHT(N''00000'' + CONVERT(NVARCHAR(10), @NextNo), 5);

            IF LEN(@NewCoNum) > 10
                THROW 50122, N''[POS-901] Format nomor Customer Order melebihi batas yang diperbolehkan.'', 1;

            INSERT INTO #GeneratedOrders
            (
                SiteRef,
                cust_po,
                order_date,
                co_num
            )
            VALUES
            (
                @OrderSiteRef,
                @OrderCustPo,
                @OrderDate,
                @NewCoNum
            );

            UPDATE i
            SET
                co_num = @NewCoNum,
                updated_by = @ReceivedBy
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            INNER JOIN #MapView AS v
              ON v.inbound_id = i.inbound_id
             AND v.view_rn = 1
             AND v.view_row_count = 1
            WHERE i.source_system = @SourceSystem
              AND i.batch_id = @BatchId
              AND i.inbound_status = N''V''
              AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                    COLLATE DATABASE_DEFAULT
                  = UPPER(LTRIM(RTRIM(@OrderSiteRef)))
                    COLLATE DATABASE_DEFAULT
              AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                    COLLATE DATABASE_DEFAULT
                  = UPPER(LTRIM(RTRIM(@OrderCustPo)))
                    COLLATE DATABASE_DEFAULT;

            FETCH NEXT FROM ValidOrderCursor
            INTO @OrderSiteRef, @OrderCustPo, @OrderDate;
        END;

        CLOSE ValidOrderCursor;
        DEALLOCATE ValidOrderCursor;

        /* =============================================================
          10. Refresh BUSINESS SOURCE after generated co_num
           ============================================================= */
        DELETE FROM #MapView;

        INSERT INTO #MapView
        (
            inbound_id,
            source_system,
            batch_id,
            row_no,
            SiteRef,
            cust_num,
            cust_seq,
            cust_po,
            order_date,
            co_num,
            co_line,
            item,
            qty_ordered,
            unit_price,
            whse,
            due_date,
            u_m,
            terms_code,
            tax_code1,
            exch_rate,
            view_row_count,
            view_rn
        )
        SELECT
            v.inbound_id,
            v.source_system,
            v.batch_id,
            v.row_no,
            v.SiteRef,
            v.cust_num,
            v.cust_seq,
            v.cust_po,
            v.order_date,
            v.co_num,
            v.co_line,
            v.item,
            v.qty_ordered,
            v.unit_price,
            v.whse,
            v.due_date,
            v.u_m,
            v.terms_code,
            v.tax_code1,
            v.exch_rate,
            COUNT(*) OVER (PARTITION BY v.inbound_id),
        ';
SET @ProdSql06 = @ProdSql06 + N'    ROW_NUMBER() OVER
            (
                PARTITION BY v.inbound_id
                ORDER BY v.cust_num, v.cust_seq, v.item
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
        WHERE v.SiteRef = @Site
          AND v.source_system = @SourceSystem
          AND v.batch_id = @BatchId;

        /* =============================================================
          11. Transfer to temp - 100% from mapping view
           ============================================================= */
        INSERT INTO dbo.ue_SMK069_temp_sales_mst
        (
            SiteRef,
            cust_num,
            order_date,
            terms_code,
            co_num,
            cust_po,
            co_line,
            unit_price,
            tax_code1,
            exch_rate,
            whse,
            item,
            qty_ordered,
            due_date,
            u_m,
            process_status,
            validation_msg,
            error_msg,
            retry_count
        )
        SELECT
            v.SiteRef,
            v.cust_num,
            v.order_date,
            v.terms_code,
            v.co_num,
            v.cust_po,
            v.co_line,
            v.unit_price,
            v.tax_code1,
            v.exch_rate,
            v.whse,
            v.item,
            v.qty_ordered,
            COALESCE(v.due_date, v.order_date),
            v.u_m,
            N''V'',
            NULL,
            NULL,
            0
        FROM #MapView AS v
        INNER JOIN dbo.ue_SMK069_pos_sales_inbound_mst AS i
          ON i.inbound_id = v.inbound_id
        WHERE v.view_rn = 1
          AND v.view_row_count = 1
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V'';

        SET @TransferredRows = @@ROWCOUNT;

        /* =============================================================
          12. Verify temp persistence from mapping-view keys
           ============================================================= */
        IF EXISTS
        (
            SELECT 1
            FROM #MapView AS v
            INNER JOIN dbo.ue_SMK069_pos_sales_inbound_mst AS i
              ON i.inbound_id = v.inbound_id
            WHERE v.view_rn = 1
              AND v.view_row_count = 1
              AND i.source_system = @SourceSystem
              AND i.batch_id = @BatchId
              AND i.inbound_status = N''V''
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.ue_SMK069_temp_sales_mst AS t
                  WHERE UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                            COLLATE DATABASE_DEFAULT
                        = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                            COLLATE DATABASE_DEFAULT
                    AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))))
                            COLLATE DATABASE_DEFAULT
                        = UPPER';
SET @ProdSql06 = @ProdSql06 + N'(LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num))))
                            COLLATE DATABASE_DEFAULT
                    AND t.co_line = v.co_line
                    AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))))
                            COLLATE DATABASE_DEFAULT
                        = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                            COLLATE DATABASE_DEFAULT
              )
        )
            THROW 50130, N''[POS-902] Data valid gagal dipindahkan ke proses Customer Order.'', 1;

        UPDATE i
        SET
            inbound_status = N''T'',
            transferred_date = GETDATE(),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #MapView AS v
          ON v.inbound_id = i.inbound_id
         AND v.view_rn = 1
         AND v.view_row_count = 1
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status = N''V'';

        /* =============================================================
          13. Final counts + Infobar
           ============================================================= */
        SELECT
            @TotalOrders = COUNT
            (
                DISTINCT NULLIF(LTRIM(RTRIM(cust_po)), N'''')
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SELECT
            @ValidOrders = COUNT
            (
                DISTINCT CASE
                    WHEN inbound_status = N''T''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            ),
            @ErrorOrders = COUNT
            (
                DISTINCT CASE
                    WHEN inbound_status = N''E''
                    THEN NULLIF(LTRIM(RTRIM(cust_po)), N'''')
                END
            )
        FROM dbo.ue_SMK069_pos_sales_inbound_mst
        WHERE SiteRef = @Site
          AND source_system = @SourceSystem
          AND batch_id = @BatchId;

        SET @ErrorDetail = NULL;

        SELECT
            @ErrorDetail =
                STUFF
                (
                    (
                        SELECT TOP (10)
                            N'' | Row ''
                            + CONVERT(NVARCHAR(20), e.row_no)
                            + CASE
                                  WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'''') IS NULL
                                  THEN N''''
                                  ELSE N'' [cust_po=''
                                     + LTRIM(RTRIM(e.cust_po))
                                     + N'']''
                              END
                            + N'': ''
                            + COALESCE
                              (
                                  NULLIF(LTRIM(RTRIM(e.validation_msg)), N''''),
                                  N''Validation error.''
         ';
SET @ProdSql06 = @ProdSql06 + N'                     )
                        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                        WHERE e.SiteRef = @Site
                          AND e.source_system = @SourceSystem
                          AND e.batch_id = @BatchId
                          AND e.inbound_status = N''E''
                        ORDER BY e.row_no
                        FOR XML PATH(N''''), TYPE
                    ).value(N''.'', N''NVARCHAR(MAX)''),
                    1,
                    3,
                    N''''
                );

        SET @Infobar =
            LEFT
            (
                N''[POS-000] Batch '' + @BatchId
                + N'' diterima. Row: '' + CONVERT(NVARCHAR(20), @ReceivedRows)
                + N''; order(cust_po): 1''
                + N''; valid: '' + CONVERT(NVARCHAR(20), @ValidOrders)
                + N''; error: '' + CONVERT(NVARCHAR(20), @ErrorOrders)
                + N''; row masuk temp: '' + CONVERT(NVARCHAR(20), @TransferredRows)
                + N''.''
                + CASE
                      WHEN @ErrorOrders > 0
                       AND NULLIF(@ErrorDetail, N'''') IS NOT NULL
                      THEN N'' ErrorDetail: '' + @ErrorDetail
                      ELSE N''''
                  END,
                4000
            );

        IF @InitialTranCount = 0
            COMMIT TRANSACTION;

        IF ISNULL(@ErrorOrders, 0) > 0
           OR ISNULL(@ValidOrders, 0) = 0
           OR ISNULL(@TransferredRows, 0) = 0
            RETURN 16;

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE
            @ErrorNumber INT = ERROR_NUMBER(),
            @ErrorLine INT = ERROR_LINE(),
            @ErrorMessage NVARCHAR(2048) = ERROR_MESSAGE();

        IF XACT_STATE() = 1
        BEGIN
            IF @InitialTranCount = 0
                ROLLBACK TRANSACTION;
            ELSE
                ROLLBACK TRANSACTION SMK069ReceiveV240;
        END
        ELSE IF XACT_STATE() = -1
        BEGIN
            IF @InitialTranCount > 0
                THROW;

            ROLLBACK TRANSACTION;
        END;

        SET @ErrorMessage = LTRIM(RTRIM(@ErrorMessage));

        SET @Infobar =
            LEFT
            (
                CASE
                    WHEN LEFT(@ErrorMessage, 5) = N''[POS-''
                     AND SUBSTRING(@ErrorMessage, 9, 1) = N'']''
                    THEN @ErrorMessage
                    ELSE
                        N''[POS-999] SMK069 Receive gagal ''
                        + CONVERT(NVARCHAR(20), @ErrorNumber)
                        + N'' line ''
                        + CONVERT(NVARCHAR(20), @ErrorLine)
                        + N'': ''
                        + @ErrorMessage
                END,
                4000
            );

        RETURN 16;
    END CATCH;
END;';
EXEC sys.sp_executesql @ProdSql06;

/* ========================================================================== 
   7. Public canonical Receive dbo.SMK069ReceivePosSalesJsonSp
   ========================================================================== */
DECLARE @ProdSql07 NVARCHAR(MAX) = N'';
SET @ProdSql07 = @ProdSql07 + N'/* =============================================================================
   Canonical source: dbo.SMK069ReceivePosSalesJsonSp
   Receive -> Validate -> Quantity Multiple Check -> Blanket Customer Order
   -----------------------------------------------------------------------------
   Date    : 2026-09-22
   Object  : dbo.SMK069ReceivePosSalesJsonSp
   Depends : dbo.SMK069ReceivePosSalesJsonCoreSp
             dbo.SMK069ProcessBatchCustomerOrdersSp
             dbo.SMK069ProcessCustomerOrderSp
             dbo.SMK030_UomConvQty2
             dbo.Getumcf

   DESIGN
   ------
   - Parameters 1-10 stay unchanged for backward-compatible IDO/Postman callers.
   - Parameters 11-14 are appended with defaults.
   - Valid rows are processed to Customer Order before a business error is
     surfaced, so partial validation does not strand valid rows in temp.
   - Mapping ValidationStatus and quantity-multiple validation run after Core receive/validate and BEFORE CO
     processing. A fractional converted base quantity rejects the whole cust_po.
   - Original successful source_system+batch_id is identified from earliest transferred inbound_id.
   - Cross-batch duplicate existing CustPO is rejected as POS-204.
   - ValidationStatus = N rejects the whole cust_po (POS-109).
   - Root quantity error code: POS-108.
   - Sibling lines of the same cust_po: POS-203 atomic-order rejection.
   - Existing POS/API behavior is preserved by default:
         @ThrowOnBusinessError = 1
     Business failure raises THROW 51069 / Success=false.
   - CSV/internal callers may set:
         @ThrowOnBusinessError = 0
     so they receive counts/Infobar and can persist C/P/E batch status.
   - IDO method must remain NOT Transactional because the per-order CO processor
     owns its transaction.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ReceivePosSalesJsonSp
    -- positions 1-10: existing public contract, DO NOT reorder
    @SourceSystem          NVARCHAR(50) = N''POS'',
    @BatchId               NVARCHAR(100),
    @PayloadJson           NVARCHAR(MAX),
    @ReceivedBy            UsernameType = NULL,
    @ReceivedRows          INT OUTPUT,
    @TotalOrders           INT OUTPUT,
    @ValidOrders           INT OUTPUT,
    @ErrorOrders           INT OUTPUT,
    @TransferredRows       INT OUTPUT,
    @Infobar               InfobarType OUTPUT,
    -- appended, defaulted: old 10-param metadata remains valid
    @ProcessedOrders       INT = NULL OUTPUT,
    @ProcessErrors         INT = NULL OUTPUT,
    @CreatedCoNums         NVARCHAR(MAX) = NULL OUTPUT,
    @ThrowOnBusinessError  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @SourceSystem = UPPER
    (
        COALESCE(NULLIF(LTRIM(RTRIM(@SourceSystem)), N''''), N''POS'')
    );
    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'''');';
SET @ProdSql07 = @ProdSql07 + N'
    SET @ReceivedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ReceivedBy)), N''''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ReceivedRows    = 0;
    SET @TotalOrders     = 0;
    SET @ValidOrders     = 0;
    SET @ErrorOrders     = 0;
    SET @TransferredRows = 0;
    SET @ProcessedOrders = 0;
    SET @ProcessErrors   = 0;
    SET @CreatedCoNums   = NULL;
    SET @Infobar         = NULL;

    DECLARE
        @ReturnCode        INT            = 0,
        @ReceiveInfo       InfobarType    = NULL,
        @SkippedOrders     INT            = 0,
        @ProcessErrorCode  NVARCHAR(20)   = NULL,
        @ProcessDetail     NVARCHAR(2800) = NULL,
        @ErrorCode         NVARCHAR(20)   = NULL,
        @ErrorList         NVARCHAR(MAX)  = NULL,
        @ErrorRowCount     INT            = 0,
        @HasRealError      BIT            = 0,
        @BusinessError     BIT            = 0,
        @HardFailed        BIT            = 0,
        @HttpError         NVARCHAR(2048) = NULL,
        @CodePos                INT            = 0,
        @QtyRejectedOrders      INT            = 0,
        @MappingRejectedOrders   INT            = 0,
        @DuplicateRejectedOrders INT            = 0,
        @DuplicateNeedsSyntheticError BIT        = 0;

    /* =========================================================================
       1. Canonical Receive/Validate
       ========================================================================= */
    EXEC @ReturnCode = dbo.SMK069ReceivePosSalesJsonCoreSp
        @SourceSystem    = @SourceSystem,
        @BatchId         = @BatchId,
        @PayloadJson     = @PayloadJson,
        @ReceivedBy      = @ReceivedBy,
        @ReceivedRows    = @ReceivedRows    OUTPUT,
        @TotalOrders     = @TotalOrders     OUTPUT,
        @ValidOrders     = @ValidOrders     OUTPUT,
        @ErrorOrders     = @ErrorOrders     OUTPUT,
        @TransferredRows = @TransferredRows OUTPUT,
        @Infobar         = @ReceiveInfo     OUTPUT;


    /* =========================================================================
       PATCH-27: propagate is_peak_season from payload to inbound + temp.
       Contract: 1 = Peak Season, 0/default = Normal.
       ========================================================================= */
    IF ISJSON(@PayloadJson) = 1
    BEGIN
        DECLARE @PeakSeasonPayload TABLE
        (
            cust_po        NVARCHAR(100) NOT NULL,
            co_line        INT           NOT NULL,
            is_peak_season INT           NOT NULL
        );

        INSERT INTO @PeakSeasonPayload (cust_po, co_line, is_peak_season)
        SELECT
            LTRIM(RTRIM(CONVERT(NVARCHAR(100), p.cust_po))),
            p.coline,
            CASE WHEN ISNULL(p.is_peak_season, 0) = 1 THEN 1 ELSE 0 END
        FROM OPENJSON(@PayloadJson)
        WITH
        (
            cust_po        NVARCHAR(100) ''$.cust_po'',
            coline         INT           ''$.coline'',
            is_peak_season IN';
SET @ProdSql07 = @ProdSql07 + N'T           ''$.is_peak_season''
        ) AS p
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), p.cust_po))), N'''') IS NOT NULL
          AND ISNULL(p.coline, 0) > 0;

        UPDATE i
        SET i.is_peak_season = p.is_peak_season
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN
        (
            SELECT cust_po, co_line, MAX(is_peak_season) AS is_peak_season
            FROM @PeakSeasonPayload
            GROUP BY cust_po, co_line
        ) AS p
            ON p.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))
           AND p.co_line = i.co_line
        WHERE i.SiteRef       = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id      = @BatchId;

        UPDATE t
        SET t.is_peak_season = p.is_peak_season
        FROM dbo.ue_SMK069_temp_sales_mst AS t
        INNER JOIN
        (
            SELECT cust_po, co_line, MAX(is_peak_season) AS is_peak_season
            FROM @PeakSeasonPayload
            GROUP BY cust_po, co_line
        ) AS p
            ON p.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))
           AND p.co_line = t.co_line
        WHERE t.SiteRef = @Site;
    END;

    /* =========================================================================
       PATCH-33: cross-batch duplicate CustPO using original inbound lineage

       Tenant-proven inbound columns:
         inbound_id, source_system, batch_id, cust_po, inbound_status

       Rule:
         - cust_po is the business idempotency key.
         - For an already-created CO, the earliest transferred inbound row
           (inbound_status = ''T'') identifies the original source_system+batch_id.
         - Replaying that same original source+batch is idempotent and allowed.
         - Sending the same existing cust_po from a different source/batch is
           rejected as POS-204 before ProcessBatch can turn it into POS-000 skip.
       ========================================================================= */
    IF ISJSON(@PayloadJson) = 1
    BEGIN
        DECLARE @DuplicateCustPo TABLE
        (
            cust_po NVARCHAR(100) NOT NULL PRIMARY KEY
        );

        ;WITH PayloadPo AS
        (
            SELECT DISTINCT
                LTRIM(RTRIM(CONVERT(NVARCHAR(100), p.cust_po))) AS cust_po
            FROM OPENJSON(@PayloadJson)
            WITH
            (
                cust_po NVARCHAR(100) ''$.cust_po''
            ) AS p
            WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), p.cust_po))), N'''') IS NOT NULL
        )
        INSERT INTO @DuplicateCustPo (cust_po)
        SELECT p.cust_po
        FROM PayloadPo AS p
        INNER JOIN dbo.co_mst AS c
            ON c.site_ref = @Site
           AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_po))) = p.cust_po
        CROSS APPLY
        (
            SELECT TOP (1)
                i0.source_system AS original_source_system,
                i0.batch_id      AS original_batch_id
            FROM dbo.ue_SMK069_pos_sales_inbound';
SET @ProdSql07 = @ProdSql07 + N'_mst AS i0
            WHERE i0.SiteRef = @Site
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), i0.cust_po))) = p.cust_po
              AND i0.inbound_status = N''T''
            ORDER BY i0.inbound_id
        ) AS orig
        WHERE UPPER(LTRIM(RTRIM(orig.original_source_system))) <> @SourceSystem
           OR LTRIM(RTRIM(orig.original_batch_id)) <> @BatchId
        GROUP BY p.cust_po;

        IF EXISTS (SELECT 1 FROM @DuplicateCustPo)
        BEGIN
            SELECT @DuplicateRejectedOrders = COUNT(*)
            FROM @DuplicateCustPo;

            UPDATE i
            SET
                i.inbound_status = N''E'',
                i.validation_msg = N''[POS-204] CustPO sudah terdaftar pada proses sebelumnya. BatchId baru tidak membuat CustPO menjadi transaksi baru.''
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.SiteRef       = @Site
              AND i.source_system = @SourceSystem
              AND i.batch_id      = @BatchId
              AND EXISTS
                  (
                      SELECT 1
                      FROM @DuplicateCustPo AS d
                      WHERE d.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))
                  );

            /* PATCH-34: duplicate gate has no matching inbound error row.
               This happens when a BatchId is reused with a different payload:
               Core replays the persisted batch, while Patch-33 evaluates the
               CustPO in the NEW payload. Preserve POS-204 explicitly instead
               of allowing error composition to fall back to ReceiveInfo POS-000. */
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                INNER JOIN @DuplicateCustPo AS d
                    ON d.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))
                WHERE i.SiteRef        = @Site
                  AND i.source_system  = @SourceSystem
                  AND i.batch_id       = @BatchId
                  AND i.inbound_status = N''E''
            )
                SET @DuplicateNeedsSyntheticError = 1;

            /*
               Never touch already-processed P rows. Remove only V rows that
               Core may have exposed for a duplicate request, so ProcessBatch
               cannot classify the duplicate as a clean skip/success.
            */
            DELETE t
            FROM dbo.ue_SMK069_temp_sales_mst AS t
            WHERE t.SiteRef = @Site
              AND t.process_status = N''V''
              AND EXISTS
                  (
                      SELECT 1
                      FROM @DuplicateCustPo AS d
                      WHERE d.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))
                  );

            SELECT @TransferredRows = COUNT(*)
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.SiteRef       = @Site
              AND i.source_system = @SourceSystem
              AND i.batch_id ';
SET @ProdSql07 = @ProdSql07 + N'     = @BatchId
              AND i.inbound_status = N''T'';

            SELECT @ValidOrders = COUNT(*)
            FROM
            (
                SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))) AS cust_po
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef       = @Site
                  AND i.source_system = @SourceSystem
                  AND i.batch_id      = @BatchId
                  AND i.inbound_status = N''T''
            ) AS v;

            SELECT @ErrorOrders = COUNT(*)
            FROM
            (
                SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))) AS cust_po
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef       = @Site
                  AND i.source_system = @SourceSystem
                  AND i.batch_id      = @BatchId
                  AND i.inbound_status = N''E''
            ) AS e;

            SET @ReturnCode = 16;
        END;
    END;

    /* =========================================================================
       PATCH-28: ValidationStatus per-item / reject whole CustPO

       Source of truth:
         dbo.ue_SMK069_pos_sales_inbound_mapping_view.ValidationStatus

       Rule:
         - ValidationStatus = ''V'' => item valid
         - ValidationStatus = ''N'' => item invalid
         - If at least one mapped item in a CustPO is ''N'', reject the whole CustPO
           before Customer Order processing.
       ========================================================================= */
    IF ISNULL(@TransferredRows, 0) > 0
    BEGIN
        DECLARE @MappingInvalidPo TABLE
        (
            cust_po NVARCHAR(100) NOT NULL PRIMARY KEY
        );

        INSERT INTO @MappingInvalidPo (cust_po)
        SELECT DISTINCT
            LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po)))
        FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
        WHERE v.SiteRef       = @Site
          AND v.source_system = @SourceSystem
          AND v.batch_id      = @BatchId
          AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))), N'''') IS NOT NULL
          AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(20), v.ValidationStatus)))) = N''N'';

        IF EXISTS (SELECT 1 FROM @MappingInvalidPo)
        BEGIN
            SELECT @MappingRejectedOrders = COUNT(*)
            FROM @MappingInvalidPo;

            /*
               The decision is CustPO-atomic. Every still-transferable inbound row
               for the rejected CustPO becomes Error. The message is deliberately
               order-level: it does not falsely claim that every sibling item is N.
            */
            UPDATE i
            SET
                i.inbound_status = N''E'',
                i.validation_msg = N''[POS-109] CustPO ditolak karena minimal satu item memiliki ValidationStatus=N.''
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.SiteRef        = @Site
              AND i.source_system  = @Sou';
SET @ProdSql07 = @ProdSql07 + N'rceSystem
              AND i.batch_id       = @BatchId
              AND i.inbound_status = N''T''
              AND EXISTS
                  (
                      SELECT 1
                      FROM @MappingInvalidPo AS p
                      WHERE p.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))
                  );

            /*
               Core may already have published the PO to temp. Remove only rows
               that are still Valid so ProcessBatch cannot create a CO for a
               CustPO rejected by ValidationStatus.
            */
            DELETE t
            FROM dbo.ue_SMK069_temp_sales_mst AS t
            WHERE t.SiteRef = @Site
              AND t.process_status = N''V''
              AND EXISTS
                  (
                      SELECT 1
                      FROM @MappingInvalidPo AS p
                      WHERE p.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))
                  );

            /* Recompute public counters after mapping business validation. */
            SELECT @TransferredRows = COUNT(*)
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.SiteRef        = @Site
              AND i.source_system  = @SourceSystem
              AND i.batch_id       = @BatchId
              AND i.inbound_status = N''T'';

            SELECT @ValidOrders = COUNT(*)
            FROM
            (
                SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))) AS cust_po
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef        = @Site
                  AND i.source_system  = @SourceSystem
                  AND i.batch_id       = @BatchId
                  AND i.inbound_status = N''T''
            ) AS v;

            SELECT @ErrorOrders = COUNT(*)
            FROM
            (
                SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))) AS cust_po
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef        = @Site
                  AND i.source_system  = @SourceSystem
                  AND i.batch_id       = @BatchId
                  AND i.inbound_status = N''E''
            ) AS e;

            SET @ReturnCode = 16;
        END;
    END;

    /* =========================================================================
       1C. Quantity multiple validation (POS-108)

       Business-supplied rule:
         itemcust mapping must match inbound is_peak_season:
           itemcust.Uf_SMK069_is_peak_season = inbound.is_peak_season
         then converted base qty = SMK030_UomConvQty2
         (
             qty_ordered,
             Getumcf(u_m, mapped item, '''', ''''),
             ''To Base''
         )

       Fractional base qty means the ordered quantity is not on an allowed
       multiple. The ENTIRE cust_po is rejected before Customer Order creation.
       ========================================================================= */
    IF ISNULL(@Tr';
SET @ProdSql07 = @ProdSql07 + N'ansferredRows, 0) > 0
    BEGIN
        DECLARE @QtyInvalid TABLE
        (
            row_no   INT           NOT NULL,
            cust_po  NVARCHAR(100) NOT NULL,
            qty_base DECIMAL(23,5) NOT NULL,
            PRIMARY KEY (row_no, cust_po)
        );

        INSERT INTO @QtyInvalid (row_no, cust_po, qty_base)
        SELECT
            i.row_no,
            LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))) AS cust_po,
            MAX(q.qty_base) AS qty_base
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN dbo.custaddr AS c
            ON i.cust_num = LEFT(c.name, 4)
           AND c.cust_num LIKE N''PH%''
           AND c.cust_seq <> 0
        INNER JOIN dbo.itemcust AS ic
            ON ic.cust_item = i.item
           AND ic.cust_num = c.cust_num
           AND ISNULL(ic.Uf_SMK069_is_peak_season, 0) = ISNULL(i.is_peak_season, 0)
        CROSS APPLY
        (
            SELECT CAST
            (
                ISNULL
                (
                    dbo.SMK030_UomConvQty2
                    (
                        i.qty_ordered,
                        ISNULL(dbo.Getumcf(i.u_m, ic.item, '''', ''''), 1),
                        ''To Base''
                    ),
                    0
                )
                AS DECIMAL(23,5)
            ) AS qty_base
        ) AS q
        WHERE i.SiteRef        = @Site
          AND i.source_system  = @SourceSystem
          AND i.batch_id       = @BatchId
          AND i.inbound_status = N''T''
          AND q.qty_base <> FLOOR(q.qty_base)
        GROUP BY
            i.row_no,
            LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)));

        IF EXISTS (SELECT 1 FROM @QtyInvalid)
        BEGIN
            SELECT @QtyRejectedOrders = COUNT(DISTINCT cust_po)
            FROM @QtyInvalid;

            /* Root error line: keep the actual quantity reason. */
            UPDATE i
            SET
                i.inbound_status = N''E'',
                i.validation_msg = LEFT
                (
                    N''[POS-108] Quantity tidak sesuai kelipatan U/M. qty_ordered=''
                    + COALESCE(CONVERT(NVARCHAR(60), i.qty_ordered), N''<kosong>'')
                    + N''; qty_base=''
                    + COALESCE(CONVERT(NVARCHAR(60), q.qty_base), N''<kosong>''),
                    1000
                )
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            INNER JOIN @QtyInvalid AS q
                ON q.row_no = i.row_no
               AND q.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))
            WHERE i.SiteRef        = @Site
              AND i.source_system  = @SourceSystem
              AND i.batch_id       = @BatchId
              AND i.inbound_status = N''T'';

            /* Atomic order rule: every sibling line in that cust_po is rejected. */
            UPDATE i
            SET
                i.inbound_status = N''E'',
                i.validation_msg = N''[POS-203] Order ditolak karena terdapat line lain yang tidak valid.''
 ';
SET @ProdSql07 = @ProdSql07 + N'           FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.SiteRef        = @Site
              AND i.source_system  = @SourceSystem
              AND i.batch_id       = @BatchId
              AND i.inbound_status = N''T''
              AND EXISTS
                  (
                      SELECT 1
                      FROM @QtyInvalid AS q
                      WHERE q.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))
                  );

            /*
               Core has already published valid rows into temp. Remove only V rows
               belonging to rejected PO(s) so ProcessBatch cannot create a CO.
            */
            DELETE t
            FROM dbo.ue_SMK069_temp_sales_mst AS t
            WHERE t.SiteRef = @Site
              AND t.process_status = N''V''
              AND EXISTS
                  (
                      SELECT 1
                      FROM @QtyInvalid AS q
                      WHERE q.cust_po = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))
                  );

            /* Recompute public counters after the extra business validation. */
            SELECT @TransferredRows = COUNT(*)
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.SiteRef        = @Site
              AND i.source_system  = @SourceSystem
              AND i.batch_id       = @BatchId
              AND i.inbound_status = N''T'';

            SELECT @ValidOrders = COUNT(*)
            FROM
            (
                SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))) AS cust_po
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef        = @Site
                  AND i.source_system  = @SourceSystem
                  AND i.batch_id       = @BatchId
                  AND i.inbound_status = N''T''
            ) AS v;

            SELECT @ErrorOrders = COUNT(*)
            FROM
            (
                SELECT DISTINCT LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po))) AS cust_po
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef        = @Site
                  AND i.source_system  = @SourceSystem
                  AND i.batch_id       = @BatchId
                  AND i.inbound_status = N''E''
            ) AS e;

            IF ISNULL(@ErrorOrders, 0) > 0
                SET @ReturnCode = 16;
        END;
    END;

    /* =========================================================================
       2. Canonical Process
          Important: valid rows are processed even if sibling orders failed
          validation. This preserves partial success and avoids stranded V rows.
       ========================================================================= */
    IF ISNULL(@TransferredRows, 0) > 0
    BEGIN
        EXEC dbo.SMK069ProcessBatchCustomerOrdersSp
            @SourceSystem    = @SourceSystem,
            @BatchId         = @BatchId,
            @ProcessedBy     = @ReceivedBy,
           ';
SET @ProdSql07 = @ProdSql07 + N' @ProcessedOrders = @ProcessedOrders  OUTPUT,
            @ProcessErrors   = @ProcessErrors    OUTPUT,
            @SkippedOrders   = @SkippedOrders    OUTPUT,
            @FirstErrorCode  = @ProcessErrorCode OUTPUT,
            @ProcessDetail   = @ProcessDetail    OUTPUT,
            @CreatedCoNums   = @CreatedCoNums    OUTPUT;

        /* Business-rejected POs are not "already processed" skips. */
        IF (@QtyRejectedOrders + @MappingRejectedOrders + @DuplicateRejectedOrders) > 0
           AND @SkippedOrders > 0
            SET @SkippedOrders =
                CASE
                    WHEN @SkippedOrders >= (@QtyRejectedOrders + @MappingRejectedOrders + @DuplicateRejectedOrders)
                    THEN @SkippedOrders - (@QtyRejectedOrders + @MappingRejectedOrders + @DuplicateRejectedOrders)
                    ELSE 0
                END;
    END
    ELSE
        SET @HardFailed = 1;

    IF ISNULL(@ReturnCode, 0) <> 0
       OR ISNULL(@ErrorOrders, 0) > 0
       OR ISNULL(@ValidOrders, 0) = 0
       OR ISNULL(@TransferredRows, 0) = 0
       OR ISNULL(@ProcessErrors, 0) > 0
        SET @BusinessError = 1;

    /* =========================================================================
       3. Error composition.
          Preserve the existing public friendly multi-error behavior for
          validation failures, then append the CO-processing outcome.
       ========================================================================= */
    IF @BusinessError = 1
    BEGIN
        IF ISNULL(@ErrorOrders, 0) > 0
           OR ISNULL(@ValidOrders, 0) = 0
           OR ISNULL(@TransferredRows, 0) = 0
           OR ISNULL(@ReturnCode, 0) <> 0
        BEGIN
            SELECT TOP (1)
                @ErrorCode =
                    CASE
                        WHEN CHARINDEX(N''[POS-'', COALESCE(e.validation_msg, N'''')) > 0
                         AND SUBSTRING
                             (
                                 e.validation_msg,
                                 CHARINDEX(N''[POS-'', e.validation_msg) + 8,
                                 1
                             ) = N'']''
                        THEN SUBSTRING
                             (
                                 e.validation_msg,
                                 CHARINDEX(N''[POS-'', e.validation_msg) + 1,
                                 7
                             )
                        ELSE NULL
                    END
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
            WHERE e.SiteRef        = @Site
              AND e.source_system  = @SourceSystem
              AND e.batch_id       = @BatchId
              AND e.inbound_status = N''E''
            ORDER BY
                CASE
                    WHEN e.validation_msg LIKE N''Order memiliki line lain%''
                      OR LEFT(LTRIM(COALESCE(e.validation_msg, N'''')), 9) = N''[POS-203]''
                    THEN 1
                    ELSE 0
                END,
                e.row_no;

       ';
SET @ProdSql07 = @ProdSql07 + N'     IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                WHERE e.SiteRef        = @Site
                  AND e.source_system  = @SourceSystem
                  AND e.batch_id       = @BatchId
                  AND e.inbound_status = N''E''
                  AND e.validation_msg NOT LIKE N''Order memiliki line lain%''
                  AND LEFT(LTRIM(COALESCE(e.validation_msg, N'''')), 9) <> N''[POS-203]''
            )
                SET @HasRealError = 1;

            SELECT @ErrorRowCount = COUNT(*)
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
            WHERE e.SiteRef        = @Site
              AND e.source_system  = @SourceSystem
              AND e.batch_id       = @BatchId
              AND e.inbound_status = N''E''
              AND
              (
                  @HasRealError = 0
                  OR
                  (
                      e.validation_msg NOT LIKE N''Order memiliki line lain%''
                      AND LEFT(LTRIM(COALESCE(e.validation_msg, N'''')), 9) <> N''[POS-203]''
                  )
              );

            SELECT @ErrorList =
                STUFF
                (
                    (
                        SELECT
                            N'' | ''
                            + CASE
                                WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'''') IS NULL
                                THEN N''''
                                ELSE N''[cust_po='' + LTRIM(RTRIM(e.cust_po)) + N''] ''
                              END
                            + CASE
                                WHEN e.validation_msg LIKE N''%Harga material%''
                                THEN
                                    N''Harga material tidak ditemukan di Infor''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''''), N''<kosong>'')
                                    + N'', order_date='' + COALESCE(CONVERT(NVARCHAR(10), e.order_date, 23), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''%Warehouse%''
                                THEN
                                    N''Warehouse tidak valid di Infor''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', whse='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''%ValidationStatus=N%''
                                THEN
                                    N''Item/CustPO tidak valid berdasarkan ValidationS';
SET @ProdSql07 = @ProdSql07 + N'tatus mapping''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN LEFT(LTRIM(COALESCE(e.validation_msg, N'''')), 9) = N''[POS-204]''
                                THEN
                                    N''CustPO sudah terdaftar pada proses sebelumnya. BatchId baru tidak membuat CustPO menjadi transaksi baru''
                                    + N'' [cust_po='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.cust_po))), N''''), N''<kosong>'')
                                    + N'', coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'']. Jika transaksi baru gunakan cust_po baru; jika retry gunakan request/batch original tanpa mengubah data.''
                                WHEN e.validation_msg LIKE N''%Quantity tidak sesuai kelipatan%''
                                THEN
                                    N''Quantity tidak sesuai kelipatan U/M''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'', qty_ordered='' + COALESCE(CONVERT(NVARCHAR(60), e.qty_ordered), N''<kosong>'')
                                    + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''%U/M%''
                                THEN
                                    N''U/M tidak valid di Infor''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''%Store/customer%''
                                THEN
                                    N''Store/customer tidak terdaftar di Infor''
                                    + N'' [custnum='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''%Material tidak terdaftar%''
                                THEN
                                    N''Material tidak terdaftar di Infor''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                    ';
SET @ProdSql07 = @ProdSql07 + N'                + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''Order memiliki line lain%''
                                  OR LEFT(LTRIM(COALESCE(e.validation_msg, N'''')), 9) = N''[POS-203]''
                                THEN
                                    N''Order ditolak karena terdapat line lain yang tidak valid''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'']''
                                ELSE
                                    N''Data payload tidak terdaftar atau tidak sesuai di Infor''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', custnum='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''''), N''<kosong>'')
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''''), N''<kosong>'')
                                    + N'', whse='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''''), N''<kosong>'')
                                    + N'']''
                              END
                        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                        WHERE e.SiteRef        = @Site
                          AND e.source_system  = @SourceSystem
                          AND e.batch_id       = @BatchId
                          AND e.inbound_status = N''E''
                          AND
                          (
                              @HasRealError = 0
                              OR
                              (
                                  e.validation_msg NOT LIKE N''Order memiliki line lain%''
                                  AND LEFT(LTRIM(COALESCE(e.validation_msg, N'''')), 9) <> N''[POS-203]''
                              )
                          )
                        ORDER BY e.row_no
                        FOR XML PATH(N''''), TYPE
                    ).value(N''.'', N''NVARCHAR(MAX)''),
                    1,
                    3,
                    N''''
                );
        END;

        /* PATCH-34: synthesize POS-204 from payload CustPO when the current
           BatchId was already persisted with a different payload/CustPO and
           therefore there is no matching inbound E row to compose from. */
        IF @DuplicateNeedsSyntheticError = 1
           AND @DuplicateRejectedOrders > 0
        BEGIN
            SET @ErrorCode = N''POS-204'';
            SET @ErrorRowCount = @DuplicateRejectedOrders;

            SELECT @ErrorList =
                STUFF
                (
                    (
                        SELE';
SET @ProdSql07 = @ProdSql07 + N'CT
                            N'' | [cust_po='' + d.cust_po + N''] ''
                            + N''CustPO sudah terdaftar pada proses sebelumnya. ''
                            + N''BatchId '' + COALESCE(@BatchId, N''<kosong>'')
                            + N'' sudah mempunyai data inbound yang berbeda atau bukan batch original CustPO ini. ''
                            + N''Jika transaksi baru gunakan CustPO dan BatchId baru; ''
                            + N''jika retry gunakan request/batch original tanpa mengubah payload.''
                        FROM @DuplicateCustPo AS d
                        ORDER BY d.cust_po
                        FOR XML PATH(N''''), TYPE
                    ).value(N''.'', N''NVARCHAR(MAX)''),
                    1,
                    3,
                    N''''
                );
        END;

        IF NULLIF(@ErrorCode, N'''') IS NULL
            SET @ErrorCode = NULLIF(@ProcessErrorCode, N'''');

        IF NULLIF(@ErrorCode, N'''') IS NULL
        BEGIN
            SET @CodePos = CHARINDEX(N''[POS-'', COALESCE(@ReceiveInfo, N''''));
            IF @CodePos > 0
               AND SUBSTRING(@ReceiveInfo, @CodePos + 8, 1) = N'']''
                SET @ErrorCode = SUBSTRING(@ReceiveInfo, @CodePos + 1, 7);
        END;

        SET @ErrorCode = COALESCE(NULLIF(@ErrorCode, N''''), N''POS-999'');

        SET @Infobar = LEFT
        (
            CASE
                WHEN @HardFailed = 0
                 AND
                 (
                     ISNULL(@ErrorOrders, 0) > 0
                     OR ISNULL(@ProcessErrors, 0) > 0
                 )
                THEN N''['' + @ErrorCode + N''] PARTIAL. ''
                ELSE N''['' + @ErrorCode + N''] Request ditolak. ''
            END
            + CASE
                WHEN NULLIF(@ErrorList, N'''') IS NULL
                THEN COALESCE(NULLIF(@ReceiveInfo, N''''), N''Business validation/process gagal.'')
                ELSE CONVERT(NVARCHAR(20), @ErrorRowCount)
                     + N'' baris bermasalah: '' + @ErrorList
              END
            + N'' ProcessedOrders='' + CONVERT(NVARCHAR(20), ISNULL(@ProcessedOrders, 0))
            + N''; ProcessErrors=''  + CONVERT(NVARCHAR(20), ISNULL(@ProcessErrors, 0))
            + N''; SkippedOrders=''  + CONVERT(NVARCHAR(20), ISNULL(@SkippedOrders, 0))
            + CASE
                  WHEN NULLIF(@CreatedCoNums, N'''') IS NULL THEN N''''
                  ELSE N''. CreatedCoNums: '' + @CreatedCoNums
              END
            + CASE
                  WHEN NULLIF(@ProcessDetail, N'''') IS NULL THEN N''''
                  ELSE N''. ProcessDetail: '' + @ProcessDetail
              END,
            4000
        );

        IF ISNULL(@ThrowOnBusinessError, 1) = 1
        BEGIN
            SET @HttpError = LEFT(@Infobar, 2048);
            THROW 51069, @HttpError, 1;
        END;

        IF @HardFailed = 1
            RETURN 16;

        RETURN 0;
    END;

    /* =========================================================================
       4. Clean success
       =======';
SET @ProdSql07 = @ProdSql07 + N'================================================================== */
    SET @Infobar = LEFT
    (
        N''[POS-000] ''
        + COALESCE(NULLIF(@ReceiveInfo, N''''), N''Receive/Validate selesai.'')
        + N'' ProcessedOrders='' + CONVERT(NVARCHAR(20), ISNULL(@ProcessedOrders, 0))
        + N''; ProcessErrors=''  + CONVERT(NVARCHAR(20), ISNULL(@ProcessErrors, 0))
        + N''; SkippedOrders=''  + CONVERT(NVARCHAR(20), ISNULL(@SkippedOrders, 0))
        + CASE
              WHEN NULLIF(@CreatedCoNums, N'''') IS NULL THEN N''''
              ELSE N''. CreatedCoNums: '' + @CreatedCoNums
          END,
        4000
    );

    RETURN 0;
END;';
EXEC sys.sp_executesql @ProdSql07;

/* ========================================================================== 
   8. CSV one-hit runner dbo.SMK069RunCsvTestBatchSp
   ========================================================================== */
DECLARE @ProdSql08 NVARCHAR(MAX) = N'';
SET @ProdSql08 = @ProdSql08 + N'/* =============================================================================
   Canonical source: dbo.SMK069RunCsvTestBatchSp
   CSV -> JSON -> SMK069ReceivePosSalesJsonSp -> Blanket CO
   -----------------------------------------------------------------------------
   Date    : 2026-09-21
   Object  : dbo.SMK069RunCsvTestBatchSp
   Depends : dbo.SMK069ReceivePosSalesJsonSp canonical entry point

   CSV owns only preflight, SiteRef normalization, CSV-to-JSON conversion and
   persistence of CSV batch/detail outcome. Receive/Validate/Process-to-CO is
   owned by dbo.SMK069ReceivePosSalesJsonSp.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069RunCsvTestBatchSp
    @BatchId               NVARCHAR(100),
    @RequestedBy           NVARCHAR(128) = NULL,
    @ReceivedRows          INT OUTPUT,
    @TotalOrders           INT OUTPUT,
    @ValidationValidOrders INT OUTPUT,
    @ValidationErrorOrders INT OUTPUT,
    @TransferredRows       INT OUTPUT,
    @ProcessedOrders       INT OUTPUT,
    @ProcessErrorOrders    INT OUTPUT,
    @Infobar               NVARCHAR(4000) OUTPUT,
    @CreatedCoNums         NVARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'''');
    SET @RequestedBy = COALESCE(NULLIF(LTRIM(RTRIM(@RequestedBy)), N''''), CONVERT(NVARCHAR(128), SUSER_SNAME()));

    SET @ReceivedRows = 0;
    SET @TotalOrders = 0;
    SET @ValidationValidOrders = 0;
    SET @ValidationErrorOrders = 0;
    SET @TransferredRows = 0;
    SET @ProcessedOrders = 0;
    SET @ProcessErrorOrders = 0;
    SET @CreatedCoNums = NULL;
    SET @Infobar = NULL;

    IF @BatchId IS NULL
    BEGIN
        SET @Infobar = N''[POS-012] batch_id wajib diisi.'';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_batch_mst AS b
        WHERE b.SiteRef = @Site
          AND b.batch_id = @BatchId
    )
    BEGIN
        UPDATE d
        SET d.SiteRef = @Site,
            d.UpdatedBy = @RequestedBy,
            d.RecordDate = GETDATE()
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        WHERE d.batch_id = @BatchId
          AND ISNULL(LTRIM(RTRIM(CONVERT(NVARCHAR(8), d.SiteRef))), N'''') <> @Site;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ue_SMK069_pos_csv_batch_mst
        WHERE SiteRef = @Site AND batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N''[POS-401] Batch CSV tidak ditemukan.'';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE SiteRef = @Site AND batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N''[POS-402] Batch CSV belum memiliki detail transaksi.'';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
    ';
SET @ProdSql08 = @ProdSql08 + N'    WHERE SiteRef = @Site
          AND batch_id = @BatchId
          AND upload_status = N''E''
          AND NULLIF(LTRIM(RTRIM(result_message)), N'''') IS NULL
    )
    BEGIN
        SET @Infobar = N''[POS-404] Batch memiliki detail parsing berstatus Error. Perbaiki CSV lalu Re-Parse sebelum Process to Blanket CO.'';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE SiteRef = @Site
          AND batch_id = @BatchId
          AND
          (
              NULLIF(LTRIM(RTRIM(custnum)), N'''') IS NULL
              OR order_date IS NULL
              OR NULLIF(LTRIM(RTRIM(cust_po)), N'''') IS NULL
              OR NULLIF(LTRIM(RTRIM(whse)), N'''') IS NULL
              OR ISNULL(coline, 0) <= 0
              OR NULLIF(LTRIM(RTRIM(item)), N'''') IS NULL
              OR ISNULL(qty_ordered, 0) <= 0
              OR NULLIF(LTRIM(RTRIM(u_m)), N'''') IS NULL
          )
    )
    BEGIN
        SET @Infobar = N''[POS-404] CSV Contract V2 belum lengkap. Wajib: custnum, order_date, cust_po, whse, coline, item, qty_ordered, u_m.'';
        RETURN 16;
    END;

    DECLARE
        @ConfiguredSourceSystem NVARCHAR(50),
        @SourceSystem NVARCHAR(50),
        @PayloadJson NVARCHAR(MAX),
        @ReceiverInfo NVARCHAR(4000),
        @ReturnCode INT = 0,
        @HardFailed BIT = 0,
        @Partial BIT = 0;

    SELECT @ConfiguredSourceSystem = UPPER(COALESCE(NULLIF(LTRIM(RTRIM(source_system)), N''''), N''POS''))
    FROM dbo.ue_SMK069_pos_csv_batch_mst
    WHERE SiteRef = @Site AND batch_id = @BatchId;

    SET @SourceSystem = CASE
        WHEN @ConfiguredSourceSystem IN (N''POS-CSV-TEST'', N''POS_CSV_TEST'', N''CSV-TEST'', N''CSV_TEST'') THEN N''POS''
        ELSE @ConfiguredSourceSystem
    END;

    UPDATE dbo.ue_SMK069_pos_csv_batch_mst
    SET batch_status = N''R'',
        started_date = GETDATE(),
        completed_date = NULL,
        result_message = N''CSV -> JSON -> SMK069ReceivePosSalesJsonSp -> Blanket CO.'',
        UpdatedBy = @RequestedBy,
        RecordDate = GETDATE()
    WHERE SiteRef = @Site AND batch_id = @BatchId;

    SELECT @PayloadJson =
    (
        SELECT
            LTRIM(RTRIM(d.custnum)) AS custnum,
            CONVERT(NVARCHAR(10), d.order_date, 23) AS order_date,
            LTRIM(RTRIM(d.cust_po)) AS cust_po,
            LTRIM(RTRIM(d.whse)) AS whse,
            d.coline AS coline,
            LTRIM(RTRIM(d.item)) AS item,
            d.qty_ordered AS qty_ordered,
            LTRIM(RTRIM(d.u_m)) AS u_m,
            ISNULL(d.is_peak_season, 0) AS is_peak_season, /* PATCH-27: peak season CSV payload */
            CONVERT(NVARCHAR(8), @Site) AS siteref,
            CASE WHEN d.due_date IS NULL THEN NULL ELSE CONVERT(NVARCHAR(10), d.due_date, 23) END AS due_date,
            NULLIF(LTRIM(RTRIM(d.terms_code)), N'''') AS terms_code,
            NULLIF(LTRIM(RTRIM(d.tax_code1)), N'''') AS tax_code1,
            d.exch_rate AS exch_rate
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
    ';
SET @ProdSql08 = @ProdSql08 + N'    WHERE d.SiteRef = @Site AND d.batch_id = @BatchId
        ORDER BY d.row_no
        FOR JSON PATH
    );

    IF ISJSON(@PayloadJson) <> 1 OR @PayloadJson = N''[]''
    BEGIN
        SET @Infobar = N''[POS-405] JSON transaksi dari CSV gagal dibentuk atau kosong.'';
        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET batch_status = N''E'', result_message = LEFT(@Infobar, 1000), completed_date = GETDATE(), UpdatedBy = @RequestedBy, RecordDate = GETDATE()
        WHERE SiteRef = @Site AND batch_id = @BatchId;
        RETURN 16;
    END;

    BEGIN TRY
        EXEC @ReturnCode = dbo.SMK069ReceivePosSalesJsonSp
            @SourceSystem = @SourceSystem,
            @BatchId = @BatchId,
            @PayloadJson = @PayloadJson,
            @ReceivedBy = @RequestedBy,
            @ReceivedRows = @ReceivedRows OUTPUT,
            @TotalOrders = @TotalOrders OUTPUT,
            @ValidOrders = @ValidationValidOrders OUTPUT,
            @ErrorOrders = @ValidationErrorOrders OUTPUT,
            @TransferredRows = @TransferredRows OUTPUT,
            @Infobar = @ReceiverInfo OUTPUT,
            @ProcessedOrders = @ProcessedOrders OUTPUT,
            @ProcessErrors = @ProcessErrorOrders OUTPUT,
            @CreatedCoNums = @CreatedCoNums OUTPUT,
            @ThrowOnBusinessError = 0;

        SET @HardFailed = CASE WHEN ISNULL(@ReturnCode, 0) <> 0 OR ISNULL(@TransferredRows, 0) = 0 THEN 1 ELSE 0 END;
        SET @Partial = CASE WHEN @HardFailed = 0 AND (ISNULL(@ValidationErrorOrders, 0) > 0 OR ISNULL(@ProcessErrorOrders, 0) > 0) THEN 1 ELSE 0 END;
        SET @Infobar = COALESCE(NULLIF(@ReceiverInfo, N''''), CASE WHEN @HardFailed = 1 THEN N''[POS-999] CSV processing gagal.'' WHEN @Partial = 1 THEN N''[POS-000] PARTIAL.'' ELSE N''[POS-000] CSV berhasil diproses sampai Blanket CO.'' END);

        UPDATE d
        SET upload_status = CASE WHEN EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef = @Site
                  AND i.source_system = @SourceSystem
                  AND i.batch_id = @BatchId
                  AND i.inbound_status = N''T''
                  AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))) COLLATE DATABASE_DEFAULT
                      = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), d.cust_po)))) COLLATE DATABASE_DEFAULT
            ) THEN N''S'' ELSE N''E'' END,
            result_message = LEFT(@Infobar, 1000),
            processed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        WHERE d.SiteRef = @Site AND d.batch_id = @BatchId;

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET batch_status = CASE WHEN @HardFailed = 1 THEN N''E'' WHEN @Partial = 1 THEN N''P'' ELSE N''C'' END,
            received_rows = ISNULL(@ReceivedRows, 0),
            total_orders = ISNULL(@TotalOrders, 0),
            validation_valid_orders = ISNULL(@ValidationValidOrders, 0),
';
SET @ProdSql08 = @ProdSql08 + N'            validation_error_orders = ISNULL(@ValidationErrorOrders, 0),
            transferred_rows = ISNULL(@TransferredRows, 0),
            processed_orders = ISNULL(@ProcessedOrders, 0),
            process_error_orders = ISNULL(@ProcessErrorOrders, 0),
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE SiteRef = @Site AND batch_id = @BatchId;

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        SET @Infobar = LEFT(N''[POS-999] CSV -> SMK069ReceivePosSalesJsonSp gagal '' + CONVERT(NVARCHAR(20), ERROR_NUMBER()) + N'': '' + ERROR_MESSAGE(), 4000);
        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET batch_status = N''E'',
            processed_orders = ISNULL(@ProcessedOrders, 0),
            process_error_orders = ISNULL(@ProcessErrorOrders, 0),
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE SiteRef = @Site AND batch_id = @BatchId;
        RETURN 16;
    END CATCH;
END;';
EXEC sys.sp_executesql @ProdSql08;

/* ==========================================================================
   Post-deploy source parity checks
   ========================================================================== */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'V') IS NULL
    THROW 520029, N'[PROD-RUNTIME] mapping view gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069CsvSplitLine') IS NULL
    THROW 520030, N'[PROD-RUNTIME] SMK069CsvSplitLine gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069ImportCsvFileSp', N'P') IS NULL
    THROW 520031, N'[PROD-RUNTIME] SMK069ImportCsvFileSp gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069ValidateCustomerSp', N'P') IS NULL
    THROW 520032, N'[PROD-RUNTIME] SMK069ValidateCustomerSp gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp', N'P') IS NULL
    THROW 520033, N'[PROD-RUNTIME] SMK069ProcessCustomerOrderSp gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069ProcessBatchCustomerOrdersSp', N'P') IS NULL
    THROW 520034, N'[PROD-RUNTIME] SMK069ProcessBatchCustomerOrdersSp gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'P') IS NULL
    THROW 520035, N'[PROD-RUNTIME] SMK069ReceivePosSalesJsonCoreSp gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp', N'P') IS NULL
    THROW 520036, N'[PROD-RUNTIME] SMK069ReceivePosSalesJsonSp gagal deploy.', 1;
IF OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp', N'P') IS NULL
    THROW 520037, N'[PROD-RUNTIME] SMK069RunCsvTestBatchSp gagal deploy.', 1;

DECLARE
    @CoreDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')), N''),
    @ReceiveDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N''),
    @OrderDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N''),
    @BatchDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessBatchCustomerOrdersSp')), N''),
    @CsvDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp')), N''),
    @ImportDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ImportCsvFileSp')), N'');

IF CHARINDEX(N'Peak Season MUST be persisted before #MapView', @CoreDef) = 0
    THROW 520038, N'[PROD-RUNTIME] Core belum membawa Patch-35 current state.', 1;

IF CHARINDEX(N'PATCH-34: synthesize POS-204 from payload CustPO', @ReceiveDef) = 0
    THROW 520039, N'[PROD-RUNTIME] Public Receive belum membawa Patch-34 current state.', 1;

IF CHARINDEX(N'ValidationStatus', @ReceiveDef) = 0
    THROW 520040, N'[PROD-RUNTIME] Public Receive belum membawa ValidationStatus gate.', 1;

IF CHARINDEX(N'INSERT INTO dbo.co_bln_mst', @OrderDef) = 0
    THROW 520041, N'[PROD-RUNTIME] Per-order processor belum membuat blanket line.', 1;

IF CHARINDEX(N'allow_on_pick_list', @OrderDef) = 0
    THROW 520042, N'[PROD-RUNTIME] Blanket-line allow_on_pick_list rule tidak ditemukan.', 1;

IF CHARINDEX(N'created_co_num', @OrderDef) = 0
    THROW 520043, N'[PROD-RUNTIME] created_co_num persistence tidak ditemukan.', 1;

IF CHARINDEX(N'[POS-302]', @BatchDef) = 0
    THROW 520044, N'[PROD-RUNTIME] Batch no-silent-success protection tidak ditemukan.', 1;

IF CHARINDEX(N'is_peak_season', @CsvDef) = 0
    THROW 520045, N'[PROD-RUNTIME] CSV runner belum membawa Peak Season.', 1;

IF CHARINDEX(N'is_peak_seson', @ImportDef) = 0
    THROW 520046, N'[PROD-RUNTIME] CSV parser Peak Season aliases belum lengkap.', 1;

PRINT N'[SMK069 PROD RUNTIME] SUCCESS - canonical current-state SQL objects deployed.';
