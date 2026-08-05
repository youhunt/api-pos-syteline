/*
    SMK069 POS CSV TEST CONSOLE
    File      : SMK069ImportCsvFileSp.sql
    Purpose   : Parse the CSV BLOB stored in dbo.ue_SMK069_pos_csv_batch_mst.csv_file
                and rebuild detail rows in dbo.ue_SMK069_pos_csv_upload_mst.

    Supported canonical headers / aliases:
      custnum       : custnum, cust_num, customer, customer_code
      order_date    : order_date, orderdate
      conum         : conum, co_num, order_no, order_number
      coline        : coline, co_line, line_no, line_number
      item          : item, item_code, sku
      qty_ordered   : qty_ordered, qty, quantity
      unit_price    : unit_price, unitprice, price
      siteref       : siteref, site_ref, site
      whse          : whse, warehouse
      due_date      : due_date, duedate
      u_m           : u_m, um, unit_of_measure
      terms_code    : terms_code, terms
      tax_code1     : tax_code1, tax_code
      exch_rate     : exch_rate, exchange_rate

    Revision 2026-08-05:
      - Fixed duplicate internal PK error caused by @Fields retaining rows across WHILE iterations.
      - Row-level table/scalar variables are now explicitly reset for every CSV row.

    Notes:
      - Designed for the functional/UAT CSV console, not the production inbound channel.
      - Supports quoted CSV values and escaped double quotes ("").
      - Embedded line breaks inside a quoted field are intentionally not supported.
      - Required fields: custnum, order_date, conum, coline, item, qty_ordered.
*/

SET NOCOUNT ON;
GO

/* ================================================================
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
        @Length    INT = LEN(ISNULL(@Line, N'') + N'#') - 1,
        @FieldNo   INT = 1,
        @InQuotes  BIT = 0,
        @Character NCHAR(1),
        @Value     NVARCHAR(MAX) = N'';

    WHILE @Pos <= @Length
    BEGIN
        SET @Character = SUBSTRING(@Line, @Pos, 1);

        IF @Character = N'"'
        BEGIN
            IF @InQuotes = 1
               AND @Pos < @Length
               AND SUBSTRING(@Line, @Pos + 1, 1) = N'"'
            BEGIN
                SET @Value = @Value + N'"';
                SET @Pos += 1;
            END
            ELSE
            BEGIN
                SET @InQuotes = CASE WHEN @InQuotes = 1 THEN 0 ELSE 1 END;
            END;
        END
        ELSE IF @Character = N',' AND @InQuotes = 0
        BEGIN
            INSERT INTO @Fields (field_no, field_value)
            VALUES (@FieldNo, @Value);

            SET @FieldNo += 1;
            SET @Value = N'';
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
END;
GO

/* ================================================================
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

    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'');
    SET @RequestedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@RequestedBy)), N''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ImportedRows = 0;
    SET @ErrorRows = 0;
    SET @Infobar = NULL;

    IF @BatchId IS NULL
    BEGIN
        SET @Infobar = N'Batch ID wajib diisi.';
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
            NULLIF(LTRIM(RTRIM(source_system)), N''),
            N'POS-CSV-TEST'
        ),
        @FileName = file_name,
        @BatchStatus = batch_status,
        @FileSize = CONVERT(INT, DATALENGTH(csv_file))
    FROM dbo.ue_SMK069_pos_csv_batch_mst
    WHERE batch_id = @BatchId;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = N'Header batch tidak ditemukan.';
        RETURN 16;
    END;

    IF @BatchStatus = N'R'
    BEGIN
        SET @Infobar = N'Batch sedang diproses dan tidak dapat diimpor ulang.';
        RETURN 16;
    END;

    IF @BatchStatus = N'C'
    BEGIN
        SET @Infobar = N'Batch sudah Completed. Gunakan New Batch untuk upload CSV baru.';
        RETURN 16;
    END;

    IF @CsvBytes IS NULL OR DATALENGTH(@CsvBytes) = 0
    BEGIN
        SET @Infobar = N'CSV file belum di-upload atau belum disimpan pada header batch.';
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

    SET @CsvText = REPLACE(@CsvText, NCHAR(0), N'');
    SET @CsvText = REPLACE(@CsvText, NCHAR(13) + NCHAR(10), NCHAR(10));
    SET @CsvText = REPLACE(@CsvText, NCHAR(13), NCHAR(10));

    IF NULLIF(LTRIM(RTRIM(REPLACE(@CsvText, NCHAR(10), N''))), N'') IS NULL
    BEGIN
        SET @Infobar = N'Isi CSV kosong.';
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
        conum          NVARCHAR(30) NULL,
        coline         INT NULL,
        item           NVARCHAR(50) NULL,
        qty_ordered    DECIMAL(18,8) NULL,
        unit_price     DECIMAL(18,8) NULL,
        siteref        NVARCHAR(8) NULL,
        whse           NVARCHAR(20) NULL,
        due_date       DATE NULL,
        u_m            NVARCHAR(20) NULL,
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
        @RawCoNum       NVARCHAR(MAX),
        @RawCoLine      NVARCHAR(MAX),
        @RawItem        NVARCHAR(MAX),
        @RawQty         NVARCHAR(MAX),
        @RawUnitPrice   NVARCHAR(MAX),
        @RawSiteRef     NVARCHAR(MAX),
        @RawWhse        NVARCHAR(MAX),
        @RawDueDate     NVARCHAR(MAX),
        @RawUM          NVARCHAR(MAX),
        @RawTerms       NVARCHAR(MAX),
        @RawTax         NVARCHAR(MAX),
        @RawExchRate    NVARCHAR(MAX),
        @OrderDate      DATE,
        @CoLine         INT,
        @QtyOrdered     DECIMAL(18,8),
        @UnitPrice      DECIMAL(18,8),
        @DueDate        DATE,
        @ExchRate       DECIMAL(18,8),
        @Message        NVARCHAR(1000);

    WHILE @CursorPos <= LEN(@CsvText + N'#') - 1
    BEGIN
        SET @NextLf = CHARINDEX(NCHAR(10), @CsvText, @CursorPos);

        IF @NextLf = 0
        BEGIN
            SET @Line = SUBSTRING(@CsvText, @CursorPos, LEN(@CsvText + N'#') - @CursorPos);
            SET @CursorPos = LEN(@CsvText + N'#');
        END
        ELSE
        BEGIN
            SET @Line = SUBSTRING(@CsvText, @CursorPos, @NextLf - @CursorPos);
            SET @CursorPos = @NextLf + 1;
        END;

        SET @PhysicalRow += 1;

        IF NULLIF(LTRIM(RTRIM(@Line)), N'') IS NULL
            CONTINUE;

        IF @HeaderFound = 0
        BEGIN
            INSERT INTO @Header (field_no, original_name, canonical_name)
            SELECT
                s.field_no,
                NULLIF(LTRIM(RTRIM(s.field_value)), N''),
                CASE
                    WHEN n.normalized IN (N'custnum', N'cust_num', N'customer', N'customer_code')
                        THEN N'custnum'
                    WHEN n.normalized IN (N'order_date', N'orderdate')
                        THEN N'order_date'
                    WHEN n.normalized IN (N'conum', N'co_num', N'order_no', N'order_number')
                        THEN N'conum'
                    WHEN n.normalized IN (N'coline', N'co_line', N'line_no', N'line_number')
                        THEN N'coline'
                    WHEN n.normalized IN (N'item', N'item_code', N'sku')
                        THEN N'item'
                    WHEN n.normalized IN (N'qty_ordered', N'qty', N'quantity')
                        THEN N'qty_ordered'
                    WHEN n.normalized IN (N'unit_price', N'unitprice', N'price')
                        THEN N'unit_price'
                    WHEN n.normalized IN (N'siteref', N'site_ref', N'site')
                        THEN N'siteref'
                    WHEN n.normalized IN (N'whse', N'warehouse')
                        THEN N'whse'
                    WHEN n.normalized IN (N'due_date', N'duedate')
                        THEN N'due_date'
                    WHEN n.normalized IN (N'u_m', N'um', N'unit_of_measure')
                        THEN N'u_m'
                    WHEN n.normalized IN (N'terms_code', N'terms')
                        THEN N'terms_code'
                    WHEN n.normalized IN (N'tax_code1', N'tax_code')
                        THEN N'tax_code1'
                    WHEN n.normalized IN (N'exch_rate', N'exchange_rate')
                        THEN N'exch_rate'
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
                            REPLACE(LTRIM(RTRIM(s.field_value)), N' ', N'_'),
                            N'-', N'_'
                        ),
                        N'.', N''
                    )
                ) AS normalized
            ) AS n;

            IF EXISTS
            (
                SELECT canonical_name
                FROM @Header
                WHERE canonical_name IS NOT NULL
                GROUP BY canonical_name
                HAVING COUNT(*) > 1
            )
            BEGIN
                SET @Infobar = N'Header CSV memiliki kolom canonical yang duplikat.';
                RETURN 16;
            END;

            IF EXISTS
            (
                SELECT required_name
                FROM
                (
                    VALUES
                        (N'custnum'),
                        (N'order_date'),
                        (N'conum'),
                        (N'coline'),
                        (N'item'),
                        (N'qty_ordered')
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
                    N'Header CSV tidak lengkap. Wajib ada: '
                    + N'custnum, order_date, conum, coline, item, qty_ordered.';
                RETURN 16;
            END;

            SET @HeaderFound = 1;
            CONTINUE;
        END;

        SET @DataRow += 1;

        DELETE FROM @Fields;

        SET @RawCustNum = NULL;
        SET @RawOrderDate = NULL;
        SET @RawCoNum = NULL;
        SET @RawCoLine = NULL;
        SET @RawItem = NULL;
        SET @RawQty = NULL;
        SET @RawUnitPrice = NULL;
        SET @RawSiteRef = NULL;
        SET @RawWhse = NULL;
        SET @RawDueDate = NULL;
        SET @RawUM = NULL;
        SET @RawTerms = NULL;
        SET @RawTax = NULL;
        SET @RawExchRate = NULL;
        SET @OrderDate = NULL;
        SET @CoLine = NULL;
        SET @QtyOrdered = NULL;
        SET @UnitPrice = NULL;
        SET @DueDate = NULL;
        SET @ExchRate = NULL;
        SET @Message = N'';

        INSERT INTO @Fields (field_no, field_value)
        SELECT field_no, NULLIF(LTRIM(RTRIM(field_value)), N'')
        FROM dbo.SMK069CsvSplitLine(@Line);

        SELECT
            @RawCustNum   = MAX(CASE WHEN h.canonical_name = N'custnum'      THEN f.field_value END),
            @RawOrderDate = MAX(CASE WHEN h.canonical_name = N'order_date'   THEN f.field_value END),
            @RawCoNum     = MAX(CASE WHEN h.canonical_name = N'conum'        THEN f.field_value END),
            @RawCoLine    = MAX(CASE WHEN h.canonical_name = N'coline'       THEN f.field_value END),
            @RawItem      = MAX(CASE WHEN h.canonical_name = N'item'         THEN f.field_value END),
            @RawQty       = MAX(CASE WHEN h.canonical_name = N'qty_ordered'  THEN f.field_value END),
            @RawUnitPrice = MAX(CASE WHEN h.canonical_name = N'unit_price'   THEN f.field_value END),
            @RawSiteRef   = MAX(CASE WHEN h.canonical_name = N'siteref'      THEN f.field_value END),
            @RawWhse      = MAX(CASE WHEN h.canonical_name = N'whse'         THEN f.field_value END),
            @RawDueDate   = MAX(CASE WHEN h.canonical_name = N'due_date'     THEN f.field_value END),
            @RawUM        = MAX(CASE WHEN h.canonical_name = N'u_m'          THEN f.field_value END),
            @RawTerms     = MAX(CASE WHEN h.canonical_name = N'terms_code'   THEN f.field_value END),
            @RawTax       = MAX(CASE WHEN h.canonical_name = N'tax_code1'    THEN f.field_value END),
            @RawExchRate  = MAX(CASE WHEN h.canonical_name = N'exch_rate'    THEN f.field_value END)
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

        IF @RawCustNum IS NULL
            SET @Message += N'custnum kosong; ';
        IF @RawOrderDate IS NULL
            SET @Message += N'order_date kosong; ';
        ELSE IF @OrderDate IS NULL
            SET @Message += N'order_date tidak valid; ';
        IF @RawCoNum IS NULL
            SET @Message += N'conum kosong; ';
        IF @RawCoLine IS NULL
            SET @Message += N'coline kosong; ';
        ELSE IF @CoLine IS NULL OR @CoLine <= 0
            SET @Message += N'coline harus bilangan > 0; ';
        IF @RawItem IS NULL
            SET @Message += N'item kosong; ';
        IF @RawQty IS NULL
            SET @Message += N'qty_ordered kosong; ';
        ELSE IF @QtyOrdered IS NULL OR @QtyOrdered <= 0
            SET @Message += N'qty_ordered harus angka > 0; ';
        IF @RawUnitPrice IS NOT NULL AND @UnitPrice IS NULL
            SET @Message += N'unit_price tidak valid; ';
        ELSE IF @UnitPrice < 0
            SET @Message += N'unit_price tidak boleh negatif; ';
        IF @RawDueDate IS NOT NULL AND @DueDate IS NULL
            SET @Message += N'due_date tidak valid; ';
        IF @RawExchRate IS NOT NULL AND (@ExchRate IS NULL OR @ExchRate <= 0)
            SET @Message += N'exch_rate harus angka > 0; ';

        IF LEN(ISNULL(@RawCustNum, N'')) > 20
            SET @Message += N'custnum melebihi 20 karakter; ';
        IF LEN(ISNULL(@RawCoNum, N'')) > 30
            SET @Message += N'conum melebihi 30 karakter; ';
        IF LEN(ISNULL(@RawItem, N'')) > 50
            SET @Message += N'item melebihi 50 karakter; ';

        INSERT INTO @ParsedRows
        (
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
            result_message,
            raw_csv_row
        )
        VALUES
        (
            @DataRow,
            LEFT(@RawCustNum, 20),
            @OrderDate,
            LEFT(@RawCoNum, 30),
            @CoLine,
            LEFT(@RawItem, 50),
            @QtyOrdered,
            @UnitPrice,
            LEFT(@RawSiteRef, 8),
            LEFT(@RawWhse, 20),
            @DueDate,
            LEFT(@RawUM, 20),
            LEFT(@RawTerms, 20),
            LEFT(@RawTax, 20),
            @ExchRate,
            CASE WHEN @Message = N'' THEN N'N' ELSE N'E' END,
            NULLIF(LEFT(@Message, 1000), N''),
            @Line
        );
    END;

    IF @HeaderFound = 0
    BEGIN
        SET @Infobar = N'Header CSV tidak ditemukan.';
        RETURN 16;
    END;

    SELECT
        @ImportedRows = COUNT(*),
        @ErrorRows = ISNULL(SUM(CASE WHEN upload_status = N'E' THEN 1 ELSE 0 END), 0)
    FROM @ParsedRows;

    IF @ImportedRows = 0
    BEGIN
        SET @Infobar = N'CSV tidak memiliki baris data setelah header.';
        RETURN 16;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE batch_id = @BatchId;

        INSERT INTO dbo.ue_SMK069_pos_csv_upload_mst
        (
            batch_id,
            source_system,
            file_name,
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
            p.conum,
            p.coline,
            p.item,
            p.qty_ordered,
            p.unit_price,
            p.siteref,
            p.whse,
            p.due_date,
            p.u_m,
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

        SET @Infobar =
            N'CSV berhasil diparsing. Rows='
            + CONVERT(NVARCHAR(20), @ImportedRows)
            + N', FormatErrors='
            + CONVERT(NVARCHAR(20), @ErrorRows)
            + N'.';

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            file_size = @FileSize,
            uploaded_date = GETDATE(),
            batch_status = CASE WHEN @ErrorRows > 0 THEN N'E' ELSE N'D' END,
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
            N'SMK069ImportCsvFileSp gagal '
            + CONVERT(NVARCHAR(20), ERROR_NUMBER())
            + N': '
            + ERROR_MESSAGE(),
            4000
        );

        RETURN 16;
    END CATCH;
END;
GO

/*
Example direct SQL test after a BLOB has been saved to the batch header:

DECLARE
    @ImportedRows INT,
    @ErrorRows INT,
    @Infobar NVARCHAR(4000),
    @ReturnCode INT;

EXEC @ReturnCode = dbo.SMK069ImportCsvFileSp
    @BatchId = N'CSV-20260805-205000-ABC123',
    @RequestedBy = N'YOHAN',
    @ImportedRows = @ImportedRows OUTPUT,
    @ErrorRows = @ErrorRows OUTPUT,
    @Infobar = @Infobar OUTPUT;

SELECT
    @ReturnCode AS ReturnCode,
    @ImportedRows AS ImportedRows,
    @ErrorRows AS ErrorRows,
    @Infobar AS Infobar;
*/
