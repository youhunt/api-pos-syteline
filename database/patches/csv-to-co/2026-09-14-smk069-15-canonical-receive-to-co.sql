/* =============================================================================
   SMK069 - Patch 15 - Make SMK069ReceivePosSalesJsonSp the canonical
                         Receive -> Validate -> Blanket Customer Order entry point
   -----------------------------------------------------------------------------
   Date    : 2026-09-14
   Object  : dbo.SMK069ReceivePosSalesJsonSp
   Depends : dbo.SMK069ReceivePosSalesJsonCoreSp
             dbo.SMK069ProcessBatchCustomerOrdersSp
             dbo.SMK069ProcessCustomerOrderSp

   DESIGN
   ------
   - Parameters 1-10 stay unchanged for backward-compatible IDO/Postman callers.
   - Parameters 11-14 are appended with defaults.
   - Valid rows are processed to Customer Order before a business error is
     surfaced, so partial validation no longer strands valid rows in temp.
   - Existing POS/API behavior is preserved by default:
         @ThrowOnBusinessError = 1
     Business failure still raises THROW 51069 / Success=false.
   - CSV/internal callers may set:
         @ThrowOnBusinessError = 0
     so they receive counts/Infobar and can persist C/P/E batch status.
   - IDO method must remain NOT Transactional because the per-order CO processor
     owns its transaction.
   - One executable batch; no GO.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ReceivePosSalesJsonSp
    -- positions 1-10: existing public contract, DO NOT reorder
    @SourceSystem          NVARCHAR(50) = N'POS',
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
        COALESCE(NULLIF(LTRIM(RTRIM(@SourceSystem)), N''), N'POS')
    );
    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'');
    SET @ReceivedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ReceivedBy)), N''),
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
        @ReturnCode       INT            = 0,
        @ReceiveInfo      InfobarType    = NULL,
        @SkippedOrders    INT            = 0,
        @ProcessErrorCode NVARCHAR(20)   = NULL,
        @ProcessDetail    NVARCHAR(2800) = NULL,
        @ErrorCode        NVARCHAR(20)   = NULL,
        @ErrorList        NVARCHAR(MAX)  = NULL,
        @ErrorRowCount    INT            = 0,
        @HasRealError     BIT            = 0,
        @BusinessError    BIT            = 0,
        @HardFailed       BIT            = 0,
        @HttpError        NVARCHAR(2048) = NULL,
        @CodePos          INT            = 0;

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
            @ProcessedOrders = @ProcessedOrders  OUTPUT,
            @ProcessErrors   = @ProcessErrors    OUTPUT,
            @SkippedOrders   = @SkippedOrders    OUTPUT,
            @FirstErrorCode  = @ProcessErrorCode OUTPUT,
            @ProcessDetail   = @ProcessDetail    OUTPUT,
            @CreatedCoNums   = @CreatedCoNums    OUTPUT;
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
                        WHEN CHARINDEX(N'[POS-', COALESCE(e.validation_msg, N'')) > 0
                         AND SUBSTRING
                             (
                                 e.validation_msg,
                                 CHARINDEX(N'[POS-', e.validation_msg) + 8,
                                 1
                             ) = N']'
                        THEN SUBSTRING
                             (
                                 e.validation_msg,
                                 CHARINDEX(N'[POS-', e.validation_msg) + 1,
                                 7
                             )
                        ELSE NULL
                    END
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
            WHERE e.SiteRef        = @Site
              AND e.source_system  = @SourceSystem
              AND e.batch_id       = @BatchId
              AND e.inbound_status = N'E'
            ORDER BY
                CASE
                    WHEN e.validation_msg LIKE N'Order memiliki line lain%'
                      OR LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) = N'[POS-203]'
                    THEN 1
                    ELSE 0
                END,
                e.row_no;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                WHERE e.SiteRef        = @Site
                  AND e.source_system  = @SourceSystem
                  AND e.batch_id       = @BatchId
                  AND e.inbound_status = N'E'
                  AND e.validation_msg NOT LIKE N'Order memiliki line lain%'
                  AND LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) <> N'[POS-203]'
            )
                SET @HasRealError = 1;

            SELECT @ErrorRowCount = COUNT(*)
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
            WHERE e.SiteRef        = @Site
              AND e.source_system  = @SourceSystem
              AND e.batch_id       = @BatchId
              AND e.inbound_status = N'E'
              AND
              (
                  @HasRealError = 0
                  OR
                  (
                      e.validation_msg NOT LIKE N'Order memiliki line lain%'
                      AND LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) <> N'[POS-203]'
                  )
              );

            SELECT @ErrorList =
                STUFF
                (
                    (
                        SELECT
                            N' | '
                            + CASE
                                WHEN NULLIF(LTRIM(RTRIM(e.cust_po)), N'') IS NULL
                                THEN N''
                                ELSE N'[cust_po=' + LTRIM(RTRIM(e.cust_po)) + N'] '
                              END
                            + CASE
                                WHEN e.validation_msg LIKE N'%Harga material%'
                                THEN
                                    N'Harga material tidak ditemukan di Infor'
                                    + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                    + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                    + N', u_m=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''), N'<kosong>')
                                    + N', order_date=' + COALESCE(CONVERT(NVARCHAR(10), e.order_date, 23), N'<kosong>')
                                    + N']'
                                WHEN e.validation_msg LIKE N'%Warehouse%'
                                THEN
                                    N'Warehouse tidak valid di Infor'
                                    + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                    + N', whse=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''), N'<kosong>')
                                    + N']'
                                WHEN e.validation_msg LIKE N'%U/M%'
                                THEN
                                    N'U/M tidak valid di Infor'
                                    + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                    + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                    + N', u_m=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''), N'<kosong>')
                                    + N']'
                                WHEN e.validation_msg LIKE N'%Store/customer%'
                                THEN
                                    N'Store/customer tidak terdaftar di Infor'
                                    + N' [custnum=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''), N'<kosong>')
                                    + N']'
                                WHEN e.validation_msg LIKE N'%Material tidak terdaftar%'
                                THEN
                                    N'Material tidak terdaftar di Infor'
                                    + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                    + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                    + N']'
                                WHEN e.validation_msg LIKE N'Order memiliki line lain%'
                                  OR LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) = N'[POS-203]'
                                THEN
                                    N'Order ditolak karena terdapat line lain yang tidak valid'
                                    + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                    + N']'
                                ELSE
                                    N'Data payload tidak terdaftar atau tidak sesuai di Infor'
                                    + N' [coline=' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N'<kosong>')
                                    + N', custnum=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cust_num))), N''), N'<kosong>')
                                    + N', item=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''), N'<kosong>')
                                    + N', u_m=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''), N'<kosong>')
                                    + N', whse=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''), N'<kosong>')
                                    + N']'
                              END
                        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
                        WHERE e.SiteRef        = @Site
                          AND e.source_system  = @SourceSystem
                          AND e.batch_id       = @BatchId
                          AND e.inbound_status = N'E'
                          AND
                          (
                              @HasRealError = 0
                              OR
                              (
                                  e.validation_msg NOT LIKE N'Order memiliki line lain%'
                                  AND LEFT(LTRIM(COALESCE(e.validation_msg, N'')), 9) <> N'[POS-203]'
                              )
                          )
                        ORDER BY e.row_no
                        FOR XML PATH(N''), TYPE
                    ).value(N'.', N'NVARCHAR(MAX)'),
                    1,
                    3,
                    N''
                );
        END;

        IF NULLIF(@ErrorCode, N'') IS NULL
            SET @ErrorCode = NULLIF(@ProcessErrorCode, N'');

        IF NULLIF(@ErrorCode, N'') IS NULL
        BEGIN
            SET @CodePos = CHARINDEX(N'[POS-', COALESCE(@ReceiveInfo, N''));
            IF @CodePos > 0
               AND SUBSTRING(@ReceiveInfo, @CodePos + 8, 1) = N']'
                SET @ErrorCode = SUBSTRING(@ReceiveInfo, @CodePos + 1, 7);
        END;

        SET @ErrorCode = COALESCE(NULLIF(@ErrorCode, N''), N'POS-999');

        SET @Infobar = LEFT
        (
            CASE
                WHEN @HardFailed = 0
                 AND
                 (
                     ISNULL(@ErrorOrders, 0) > 0
                     OR ISNULL(@ProcessErrors, 0) > 0
                 )
                THEN N'[' + @ErrorCode + N'] PARTIAL. '
                ELSE N'[' + @ErrorCode + N'] Request ditolak. '
            END
            + CASE
                WHEN NULLIF(@ErrorList, N'') IS NULL
                THEN COALESCE(NULLIF(@ReceiveInfo, N''), N'Business validation/process gagal.')
                ELSE CONVERT(NVARCHAR(20), @ErrorRowCount)
                     + N' baris bermasalah: ' + @ErrorList
              END
            + N' ProcessedOrders=' + CONVERT(NVARCHAR(20), ISNULL(@ProcessedOrders, 0))
            + N'; ProcessErrors='  + CONVERT(NVARCHAR(20), ISNULL(@ProcessErrors, 0))
            + N'; SkippedOrders='  + CONVERT(NVARCHAR(20), ISNULL(@SkippedOrders, 0))
            + CASE
                  WHEN NULLIF(@CreatedCoNums, N'') IS NULL THEN N''
                  ELSE N'. CreatedCoNums: ' + @CreatedCoNums
              END
            + CASE
                  WHEN NULLIF(@ProcessDetail, N'') IS NULL THEN N''
                  ELSE N'. ProcessDetail: ' + @ProcessDetail
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
       ========================================================================= */
    SET @Infobar = LEFT
    (
        N'[POS-000] '
        + COALESCE(NULLIF(@ReceiveInfo, N''), N'Receive/Validate selesai.')
        + N' ProcessedOrders=' + CONVERT(NVARCHAR(20), ISNULL(@ProcessedOrders, 0))
        + N'; ProcessErrors='  + CONVERT(NVARCHAR(20), ISNULL(@ProcessErrors, 0))
        + N'; SkippedOrders='  + CONVERT(NVARCHAR(20), ISNULL(@SkippedOrders, 0))
        + CASE
              WHEN NULLIF(@CreatedCoNums, N'') IS NULL THEN N''
              ELSE N'. CreatedCoNums: ' + @CreatedCoNums
          END,
        4000
    );

    RETURN 0;
END;
