/* =============================================================================
   Canonical source: dbo.SMK069RunCsvTestBatchSp
   CSV -> JSON -> SMK069ReceivePosSalesJsonSp -> Blanket CO
   -----------------------------------------------------------------------------
   Date    : 2026-09-14
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

    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'');
    SET @RequestedBy = COALESCE(NULLIF(LTRIM(RTRIM(@RequestedBy)), N''), CONVERT(NVARCHAR(128), SUSER_SNAME()));

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
        SET @Infobar = N'[POS-012] batch_id wajib diisi.';
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
          AND ISNULL(LTRIM(RTRIM(CONVERT(NVARCHAR(8), d.SiteRef))), N'') <> @Site;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ue_SMK069_pos_csv_batch_mst
        WHERE SiteRef = @Site AND batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N'[POS-401] Batch CSV tidak ditemukan.';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE SiteRef = @Site AND batch_id = @BatchId
    )
    BEGIN
        SET @Infobar = N'[POS-402] Batch CSV belum memiliki detail transaksi.';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_upload_mst
        WHERE SiteRef = @Site
          AND batch_id = @BatchId
          AND upload_status = N'E'
          AND NULLIF(LTRIM(RTRIM(result_message)), N'') IS NULL
    )
    BEGIN
        SET @Infobar = N'[POS-404] Batch memiliki detail parsing berstatus Error. Perbaiki CSV lalu Re-Parse sebelum Process to Blanket CO.';
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
              NULLIF(LTRIM(RTRIM(custnum)), N'') IS NULL
              OR order_date IS NULL
              OR NULLIF(LTRIM(RTRIM(cust_po)), N'') IS NULL
              OR NULLIF(LTRIM(RTRIM(whse)), N'') IS NULL
              OR ISNULL(coline, 0) <= 0
              OR NULLIF(LTRIM(RTRIM(item)), N'') IS NULL
              OR ISNULL(qty_ordered, 0) <= 0
              OR NULLIF(LTRIM(RTRIM(u_m)), N'') IS NULL
          )
    )
    BEGIN
        SET @Infobar = N'[POS-404] CSV Contract V2 belum lengkap. Wajib: custnum, order_date, cust_po, whse, coline, item, qty_ordered, u_m.';
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

    SELECT @ConfiguredSourceSystem = UPPER(COALESCE(NULLIF(LTRIM(RTRIM(source_system)), N''), N'POS'))
    FROM dbo.ue_SMK069_pos_csv_batch_mst
    WHERE SiteRef = @Site AND batch_id = @BatchId;

    SET @SourceSystem = CASE
        WHEN @ConfiguredSourceSystem IN (N'POS-CSV-TEST', N'POS_CSV_TEST', N'CSV-TEST', N'CSV_TEST') THEN N'POS'
        ELSE @ConfiguredSourceSystem
    END;

    UPDATE dbo.ue_SMK069_pos_csv_batch_mst
    SET batch_status = N'R',
        started_date = GETDATE(),
        completed_date = NULL,
        result_message = N'CSV -> JSON -> SMK069ReceivePosSalesJsonSp -> Blanket CO.',
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
            CONVERT(NVARCHAR(8), @Site) AS siteref,
            CASE WHEN d.due_date IS NULL THEN NULL ELSE CONVERT(NVARCHAR(10), d.due_date, 23) END AS due_date,
            NULLIF(LTRIM(RTRIM(d.terms_code)), N'') AS terms_code,
            NULLIF(LTRIM(RTRIM(d.tax_code1)), N'') AS tax_code1,
            d.exch_rate AS exch_rate
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        WHERE d.SiteRef = @Site AND d.batch_id = @BatchId
        ORDER BY d.row_no
        FOR JSON PATH
    );

    IF ISJSON(@PayloadJson) <> 1 OR @PayloadJson = N'[]'
    BEGIN
        SET @Infobar = N'[POS-405] JSON transaksi dari CSV gagal dibentuk atau kosong.';
        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET batch_status = N'E', result_message = LEFT(@Infobar, 1000), completed_date = GETDATE(), UpdatedBy = @RequestedBy, RecordDate = GETDATE()
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
        SET @Infobar = COALESCE(NULLIF(@ReceiverInfo, N''), CASE WHEN @HardFailed = 1 THEN N'[POS-999] CSV processing gagal.' WHEN @Partial = 1 THEN N'[POS-000] PARTIAL.' ELSE N'[POS-000] CSV berhasil diproses sampai Blanket CO.' END);

        UPDATE d
        SET upload_status = CASE WHEN EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
                WHERE i.SiteRef = @Site
                  AND i.source_system = @SourceSystem
                  AND i.batch_id = @BatchId
                  AND i.inbound_status = N'T'
                  AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))) COLLATE DATABASE_DEFAULT
                      = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), d.cust_po)))) COLLATE DATABASE_DEFAULT
            ) THEN N'S' ELSE N'E' END,
            result_message = LEFT(@Infobar, 1000),
            processed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        WHERE d.SiteRef = @Site AND d.batch_id = @BatchId;

        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET batch_status = CASE WHEN @HardFailed = 1 THEN N'E' WHEN @Partial = 1 THEN N'P' ELSE N'C' END,
            received_rows = ISNULL(@ReceivedRows, 0),
            total_orders = ISNULL(@TotalOrders, 0),
            validation_valid_orders = ISNULL(@ValidationValidOrders, 0),
            validation_error_orders = ISNULL(@ValidationErrorOrders, 0),
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
        SET @Infobar = LEFT(N'[POS-999] CSV -> SMK069ReceivePosSalesJsonSp gagal ' + CONVERT(NVARCHAR(20), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE(), 4000);
        UPDATE dbo.ue_SMK069_pos_csv_batch_mst
        SET batch_status = N'E',
            processed_orders = ISNULL(@ProcessedOrders, 0),
            process_error_orders = ISNULL(@ProcessErrorOrders, 0),
            result_message = LEFT(@Infobar, 1000),
            completed_date = GETDATE(),
            UpdatedBy = @RequestedBy,
            RecordDate = GETDATE()
        WHERE SiteRef = @Site AND batch_id = @BatchId;
        RETURN 16;
    END CATCH;
END;

GO
