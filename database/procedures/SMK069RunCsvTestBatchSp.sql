/*
    Procedure : dbo.SMK069RunCsvTestBatchSp
    Purpose   : CSV Test Console wrapper:
                CSV detail -> JSON -> inbound -> mapping -> validation
                -> ue_SMK069_temp_sales_mst

    POS CONTRACT V2:
      - CSV input carries custnum, order_date, cust_po, whse, coline,
        item, qty_ordered, and u_m.
      - conum is NOT supplied by CSV/POS; Receive generates RYYMM#####.
      - unit_price is NOT supplied by CSV/POS; Receive resolves pricing
        from itemcustprice_mst.
      - This wrapper DOES NOT create a Customer Order.
      - Customer Order creation is performed from
        SMK API SALES ERROR PROCESSING via Process/Reprocess.
      - The existing procedure signature is retained for IDO compatibility.
      - Contract V2.2 refuses Import & Validate when parsed detail still has
        blank cust_po/whse/u_m, preventing a mixed parser deployment from
        reaching Receive.
*/
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
    @Infobar               NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'');
    SET @RequestedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@RequestedBy)), N''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ReceivedRows = 0;
    SET @TotalOrders = 0;
    SET @ValidationValidOrders = 0;
    SET @ValidationErrorOrders = 0;
    SET @TransferredRows = 0;

    /*
        These outputs are retained only for compatibility with the existing
        IDO method signature. Customer Order processing is not executed here.
    */
    SET @ProcessedOrders = 0;
    SET @ProcessErrorOrders = 0;
    SET @Infobar = NULL;

    IF @BatchId IS NULL
    BEGIN
        SET @Infobar = N'Batch ID wajib diisi.';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_batch_mst
        WHERE batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N'Header batch tidak ditemukan.';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_batch_mst
        WHERE batch_id = @BatchId
          AND batch_status = N'R'
    )
    BEGIN
        SET @Infobar = N'Batch sedang diproses.';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N'Batch belum memiliki detail transaksi.';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE batch_id = @BatchId
          AND ISNULL(upload_status, N'N') <> N'E'
          AND
          (
              NULLIF(LTRIM(RTRIM(cust_po)), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(whse)), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(u_m)), N'') IS NULL
          )
    )
    BEGIN
        SET @Infobar =
            N'CSV Contract V2 belum lengkap pada parsed detail: '
            + N'cust_po, whse, dan u_m wajib terisi. '
            + N'Re-Parse CSV menggunakan SMK069ImportCsvFileSp V2 terbaru.';

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status = N'E',
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE batch_id = @BatchId
          AND upload_status = N'E'
    )
    BEGIN
        SET @Infobar =
            N'Batch memiliki detail hasil parsing berstatus Error. '
            + N'Perbaiki CSV lalu jalankan Parse CSV to Rows kembali.';

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status = N'E',
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        RETURN 16;
    END;

    DECLARE
        @ConfiguredSourceSystem NVARCHAR(50),
        @SourceSystem           NVARCHAR(50),
        @PayloadJson            NVARCHAR(MAX),
        @ReturnCode             INT = 0,
        @BusinessFailed         BIT = 0,
        @FirstValidationError   NVARCHAR(1000),
        @ReceiverInfo           NVARCHAR(4000);

    SELECT
        @ConfiguredSourceSystem = UPPER
        (
            COALESCE
            (
                NULLIF(LTRIM(RTRIM(source_system)), N''),
                N'POS'
            )
        )
    FROM dbo.ue_SMK069_pos_csv_batch_mst
    WHERE batch_id = @BatchId;

    /*
       source_system is the field-mapping namespace.
       POS-CSV-TEST was only a console label; the deployed mapping namespace is POS.
    */
    SET @SourceSystem =
        CASE
            WHEN @ConfiguredSourceSystem IN
                 (N'POS-CSV-TEST', N'POS_CSV_TEST', N'CSV-TEST', N'CSV_TEST')
            THEN N'POS'
            ELSE @ConfiguredSourceSystem
        END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_field_map_mst
        WHERE UPPER(LTRIM(RTRIM(source_system))) COLLATE DATABASE_DEFAULT
              = @SourceSystem COLLATE DATABASE_DEFAULT
          AND is_active = 1
    )
    BEGIN
        SET @Infobar = LEFT
        (
            N'Tidak ada field mapping aktif untuk SourceSystem '
            + COALESCE(@SourceSystem, N'<NULL>')
            + N'. Configured source: '
            + COALESCE(@ConfiguredSourceSystem, N'<NULL>')
            + N'.',
            4000
        );

        UPDATE dbo.ue_SMK069_pos_csv_upload_mst
        SET
            upload_status = N'E',
            result_message = LEFT(@Infobar, 1000),
            processed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status = N'E',
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        RETURN 16;
    END;

    UPDATE dbo.ue_SMK069_pos_csv_batch_mst
    SET
        batch_status = N'R',
        started_date = GETDATE(),
        completed_date = NULL,
        result_message =
            N'Batch sedang diimpor dan divalidasi. Mapping source: '
            + COALESCE(@SourceSystem, N'<NULL>')
            + N'.',
        UpdatedBy = @RequestedBy,
        RecordDate = GETDATE()
    WHERE batch_id = @BatchId;

    SELECT
        @PayloadJson =
        (
            SELECT
                LTRIM(RTRIM(d.custnum)) AS custnum,
                CONVERT(NVARCHAR(10), d.order_date, 23) AS order_date,
                LTRIM(RTRIM(d.cust_po)) AS cust_po,
                NULLIF(LTRIM(RTRIM(d.whse)), N'') AS whse,
                d.coline AS coline,
                LTRIM(RTRIM(d.item)) AS item,
                d.qty_ordered AS qty_ordered,
                NULLIF(LTRIM(RTRIM(d.u_m)), N'') AS u_m,

                /* Optional/non-POS-contract fields retained for UAT flexibility. */
                NULLIF(LTRIM(RTRIM(d.siteref)), N'') AS siteref,
                CASE
                    WHEN d.due_date IS NULL THEN NULL
                    ELSE CONVERT(NVARCHAR(10), d.due_date, 23)
                END AS due_date,
                NULLIF(LTRIM(RTRIM(d.terms_code)), N'') AS terms_code,
                NULLIF(LTRIM(RTRIM(d.tax_code1)), N'') AS tax_code1,
                d.exch_rate AS exch_rate
            FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
            WHERE d.batch_id = @BatchId
            ORDER BY d.row_no
            FOR JSON PATH
        );

    IF ISJSON(@PayloadJson) <> 1 OR @PayloadJson = N'[]'
    BEGIN
        SET @Infobar = N'JSON transaksi gagal dibentuk atau kosong.';

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status = N'E',
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        RETURN 16;
    END;

    BEGIN TRY
        /*
            Receive-only path:
              raw inbound -> field mapping -> validation -> temp sales (status V)

            It intentionally does NOT call:
              dbo.SMK069ReceiveAndProcessPosSalesJsonSp
        */
        EXEC @ReturnCode = dbo.SMK069ReceivePosSalesJsonSp
            @SourceSystem    = @SourceSystem,
            @BatchId         = @BatchId,
            @PayloadJson     = @PayloadJson,
            @ReceivedBy      = @RequestedBy,
            @ReceivedRows    = @ReceivedRows OUTPUT,
            @TotalOrders     = @TotalOrders OUTPUT,
            @ValidOrders     = @ValidationValidOrders OUTPUT,
            @ErrorOrders     = @ValidationErrorOrders OUTPUT,
            @TransferredRows = @TransferredRows OUTPUT,
            @Infobar         = @ReceiverInfo OUTPUT;

        IF ISNULL(@ValidationErrorOrders, 0) > 0
           OR (ISNULL(@ReceivedRows, 0) > 0 AND ISNULL(@TotalOrders, 0) = 0)
        BEGIN
            SELECT TOP (1)
                @FirstValidationError =
                    NULLIF(LTRIM(RTRIM(validation_msg)), N'')
            FROM dbo.ue_SMK069_pos_sales_inbound_mst
            WHERE UPPER(LTRIM(RTRIM(source_system))) COLLATE DATABASE_DEFAULT
                  = @SourceSystem COLLATE DATABASE_DEFAULT
              AND LTRIM(RTRIM(batch_id)) COLLATE DATABASE_DEFAULT
                  = @BatchId COLLATE DATABASE_DEFAULT
              AND inbound_status = N'E'
              AND NULLIF(LTRIM(RTRIM(validation_msg)), N'') IS NOT NULL
            ORDER BY row_no, inbound_id;
        END;

        SET @Infobar = LEFT
        (
            COALESCE(NULLIF(@ReceiverInfo, N''), N'Import dan validasi selesai.')
            + N' Mapping source: '
            + COALESCE(@ConfiguredSourceSystem, N'<NULL>')
            + N' -> '
            + COALESCE(@SourceSystem, N'<NULL>')
            + N'; row masuk temp: '
            + CONVERT(NVARCHAR(20), ISNULL(@TransferredRows, 0))
            + CASE
                WHEN @FirstValidationError IS NULL THEN N''
                ELSE N'; contoh error validasi: ' + @FirstValidationError
              END
            + CASE
                WHEN ISNULL(@ValidationValidOrders, 0) > 0
                     AND ISNULL(@ValidationErrorOrders, 0) = 0
                THEN
                    N'; Customer Order belum dibuat. '
                    + N'Lanjutkan melalui form SMK API SALES ERROR PROCESSING.'
                ELSE N''
              END,
            4000
        );

        /*
            Success here means:
              - JSON received,
              - canonical POS order formed from SiteRef + cust_po,
              - Receive generated final co_num and resolved unit_price,
              - every order passed validation,
              - valid rows transferred to temp sales.

            Customer Order creation is deliberately excluded.
        */
        IF ISNULL(@ReturnCode, 0) <> 0
           OR ISNULL(@ReceivedRows, 0) = 0
           OR ISNULL(@TotalOrders, 0) = 0
           OR ISNULL(@ValidationValidOrders, 0) = 0
           OR ISNULL(@ValidationErrorOrders, 0) > 0
           OR ISNULL(@TransferredRows, 0) = 0
        BEGIN
            SET @BusinessFailed = 1;

            IF ISNULL(@ReturnCode, 0) = 0
                SET @ReturnCode = 16;

            IF ISNULL(@ReceivedRows, 0) > 0
               AND ISNULL(@TotalOrders, 0) = 0
               AND @FirstValidationError IS NULL
            BEGIN
                SET @Infobar = LEFT
                (
                    @Infobar
                    + N'; tidak ada cust_po canonical yang terbentuk. '
                    + N'Periksa mapping SourceSystem dan field wajib cust_po.',
                    4000
                );
            END;
        END;

        UPDATE dbo.ue_SMK069_pos_csv_upload_mst
        SET
            upload_status = CASE WHEN @BusinessFailed = 1 THEN N'E' ELSE N'S' END,
            result_message = LEFT
            (
                COALESCE(NULLIF(@Infobar, N''), N'Import dan validasi gagal.'),
                1000
            ),
            processed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status = CASE WHEN @BusinessFailed = 1 THEN N'E' ELSE N'C' END,
            received_rows = ISNULL(@ReceivedRows, 0),
            total_orders = ISNULL(@TotalOrders, 0),
            validation_valid_orders = ISNULL(@ValidationValidOrders, 0),
            validation_error_orders = ISNULL(@ValidationErrorOrders, 0),
            transferred_rows = ISNULL(@TransferredRows, 0),

            /*
                No Customer Order processing occurs in this wrapper.
                Keep legacy result fields explicitly zero.
            */
            processed_orders = 0,
            process_error_orders = 0,

            result_message = LEFT
            (
                COALESCE(NULLIF(@Infobar, N''), N'Import dan validasi gagal.'),
                1000
            ),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        RETURN @ReturnCode;
    END TRY
    BEGIN CATCH
        SET @Infobar = LEFT
        (
            N'SMK069RunCsvTestBatchSp gagal '
            + CONVERT(NVARCHAR(20), ERROR_NUMBER())
            + N': '
            + ERROR_MESSAGE(),
            4000
        );

        UPDATE dbo.ue_SMK069_pos_csv_upload_mst
        SET
            upload_status = N'E',
            result_message = LEFT(@Infobar, 1000),
            processed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET
            batch_status = N'E',
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            processed_orders = 0,
            process_error_orders = 0,
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE batch_id = @BatchId;

        RETURN 16;
    END CATCH;
END;
GO
