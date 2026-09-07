/* =============================================================================
   SMK069 - Partial Success Enablement, Patch 02 of 03
   -----------------------------------------------------------------------------
   Object   : dbo.SMK069ReceiveAndProcessPosSalesJsonSp      (PATCHED)
   Date     : 2026-09-04
   Depends  : Patch 01 (dbo.SMK069ProcessBatchCustomerOrdersSp)
              dbo.SMK069ReceivePosSalesJsonCoreSp            (UNCHANGED)

   >>> BEFORE APPLY DATABASE <<<
   Diff the parameter block below against the tenant. Positions 1-12 MUST stay
   exactly as they are today, because the IDO method ue_SMK069TempSales.
   SMK069ReceiveAndProcessPosSalesJsonSp binds its parameters BY POSITION.
   @CreatedCoNums is appended as position 13 WITH A DEFAULT, so the existing
   12-parameter method metadata keeps working untouched. Add parameter 13 to the
   IDO method only when you actually want the co_num list back.

   WHAT CHANGED AND WHY
   --------------------
   1. THE VALIDATION GATE.

      was:  IF @ReturnCode <> 0 OR @ValidationErrors > 0 OR @TransferredRows = 0
      now:  IF @TransferredRows = 0

      SMK069ReceivePosSalesJsonCoreSp validates each atomic order separately,
      transfers only the valid ones to ue_SMK069_temp_sales_mst, and COMMITS
      before returning 16. So the old gate threw away work that was already
      persisted: on a batch of ten orders with one bad order, nine orders sat in
      temp at process_status = 'V' with a generated co_num, and nothing ever
      picked them up. Re-sending the same batch_id hit Core's idempotent replay
      branch and returned 16 again; re-sending under a NEW batch_id was rejected
      with [POS-204] because those cust_po values were already in temp. The rows
      were unreachable except by calling Process manually per order.

      Core returns 16 for two very different situations. @TransferredRows is the
      discriminator: it is 0 on genuine total failure (bad site, malformed JSON,
      CATCH) and greater than 0 whenever at least one order landed.

   2. THROW 51071 REMOVED.

      Process failures are per-order by construction and are already recorded in
      ue_SMK069_temp_sales_mst (process_status = 'E', retry_count + 1). Throwing
      aborted the T-SQL batch, so NONE of the OUTPUT parameters reached the
      caller: the client could not tell how many orders succeeded, which co_num
      values were created, or what to retry. The counts are now returned.

   3. THROW 51070 KEPT, but only for total failure (@TransferredRows = 0).
      Existing callers that rely on a hard error for a rejected batch keep it.

   NEW RESULT CONTRACT
   -------------------
   ReturnValue 0  + @ProcessErrors = 0 and @ValidationErrors = 0  -> full success
   ReturnValue 0  + @ProcessErrors > 0 or  @ValidationErrors > 0  -> PARTIAL
   THROW 51070                                                    -> nothing landed

   A caller must branch on @ValidationErrors / @ProcessErrors, not on
   ReturnValue alone. @Infobar carries the literal marker "PARTIAL" so a partial
   batch is never mistaken for a clean one in logs.

   TRANSACTION REQUIREMENT
   -----------------------
   The IDO method must remain NOT Transactional. Verified 2026-09-04.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ReceiveAndProcessPosSalesJsonSp
    -- ----- positions 1-12: UNCHANGED, do not reorder -------------------------
    @SourceSystem      NVARCHAR(50) = N'POS',
    @BatchId           NVARCHAR(100),
    @PayloadJson       NVARCHAR(MAX),
    @RequestedBy       UsernameType = NULL,
    @ReceivedRows      INT OUTPUT,
    @TotalOrders       INT OUTPUT,
    @ValidOrders       INT OUTPUT,
    @ValidationErrors  INT OUTPUT,
    @TransferredRows   INT OUTPUT,
    @ProcessedOrders   INT OUTPUT,
    @ProcessErrors     INT OUTPUT,
    @Infobar           InfobarType OUTPUT,
    -- ----- position 13: NEW, defaulted so old metadata still binds -----------
    @CreatedCoNums     NVARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- ACTIVE SITE CONTEXT (SMK069 Site-Aware Hardening 2026-09-03)
    ----------------------------------------------------------------
    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    DECLARE
        @ReceiveInfo       InfobarType,
        @ReturnCode        INT,
        @ProcessDetail     NVARCHAR(2800) = NULL,
        @ReceiveErrorCode  NVARCHAR(20)   = NULL,
        @ProcessErrorCode  NVARCHAR(20)   = NULL,
        @SkippedOrders     INT            = 0,
        @CodePos           INT            = 0;

    SET @ProcessedOrders = 0;
    SET @ProcessErrors   = 0;
    SET @CreatedCoNums   = NULL;
    SET @Infobar         = NULL;

    /* =========================================================================
       1. Receive. Core validates per atomic order and commits what is valid.
       ========================================================================= */
    EXEC @ReturnCode = dbo.SMK069ReceivePosSalesJsonCoreSp
        @SourceSystem    = @SourceSystem,
        @BatchId         = @BatchId,
        @PayloadJson     = @PayloadJson,
        @ReceivedBy      = @RequestedBy,
        @ReceivedRows    = @ReceivedRows    OUTPUT,
        @TotalOrders     = @TotalOrders     OUTPUT,
        @ValidOrders     = @ValidOrders     OUTPUT,
        @ErrorOrders     = @ValidationErrors OUTPUT,
        @TransferredRows = @TransferredRows OUTPUT,
        @Infobar         = @ReceiveInfo     OUTPUT;

    /* =========================================================================
       2. Total failure only. Partial validation errors fall through to Process.
       ========================================================================= */
    IF ISNULL(@TransferredRows, 0) = 0
    BEGIN
        /* Root receive code: same rule as Public Receive / CSV. */
        SELECT TOP (1)
            @ReceiveErrorCode =
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
          AND e.source_system  = UPPER(LTRIM(RTRIM(@SourceSystem)))
          AND e.batch_id       = LTRIM(RTRIM(@BatchId))
          AND e.inbound_status = N'E'
        ORDER BY
            CASE
                WHEN e.validation_msg LIKE N'Order memiliki line lain%' THEN 1
                ELSE 0
            END,
            e.row_no;

        IF NULLIF(@ReceiveErrorCode, N'') IS NULL
        BEGIN
            SET @CodePos = CHARINDEX(N'[POS-', COALESCE(@ReceiveInfo, N''));
            IF @CodePos > 0
               AND SUBSTRING(@ReceiveInfo, @CodePos + 1, 7) = N'POS-000'
                SET @CodePos = CHARINDEX(N'[POS-', @ReceiveInfo, @CodePos + 5);
            IF @CodePos > 0
               AND SUBSTRING(@ReceiveInfo, @CodePos + 8, 1) = N']'
                SET @ReceiveErrorCode = SUBSTRING(@ReceiveInfo, @CodePos + 1, 7);
        END;

        SET @ReceiveErrorCode = COALESCE(NULLIF(@ReceiveErrorCode, N''), N'POS-999');

        SET @Infobar = LEFT
        (
            N'[' + @ReceiveErrorCode + N'] Receive/Validate gagal. '
            + N'Tidak ada order yang masuk ke proses Customer Order. '
            + COALESCE(NULLIF(@ReceiveInfo, N''), N'Business validation gagal.'),
            4000
        );

        DECLARE @ReceiveHttpError NVARCHAR(2048);
        SET @ReceiveHttpError = LEFT(@Infobar, 2048);
        THROW 51070, @ReceiveHttpError, 1;
    END;

    /* =========================================================================
       3. Process every pending order of the batch, one transaction each.
          Orders already at 'P' are skipped, so a retry reports honest counts.
       ========================================================================= */
    EXEC dbo.SMK069ProcessBatchCustomerOrdersSp
        @SourceSystem    = @SourceSystem,
        @BatchId         = @BatchId,
        @ProcessedBy     = @RequestedBy,
        @ProcessedOrders = @ProcessedOrders  OUTPUT,
        @ProcessErrors   = @ProcessErrors    OUTPUT,
        @SkippedOrders   = @SkippedOrders    OUTPUT,
        @FirstErrorCode  = @ProcessErrorCode OUTPUT,
        @ProcessDetail   = @ProcessDetail    OUTPUT,
        @CreatedCoNums   = @CreatedCoNums    OUTPUT;

    /* =========================================================================
       4. Compose one honest result line.
       ========================================================================= */
    SET @Infobar = LEFT
    (
        CASE
            WHEN ISNULL(@ValidationErrors, 0) > 0
              OR ISNULL(@ProcessErrors, 0) > 0
            THEN N'[' + COALESCE(NULLIF(@ProcessErrorCode, N''), N'POS-000')
                 + N'] PARTIAL. '
            ELSE N'[POS-000] '
        END
        + COALESCE(NULLIF(@ReceiveInfo, N''), N'Receive selesai.')
        + N' ProcessedOrders=' + CONVERT(NVARCHAR(20), @ProcessedOrders)
        + N'; ProcessErrors='  + CONVERT(NVARCHAR(20), @ProcessErrors)
        + N'; SkippedOrders='  + CONVERT(NVARCHAR(20), @SkippedOrders)
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

    /*
        No THROW for per-order failures. The successful Customer Orders are
        already committed and the failed orders are parked in
        ue_SMK069_temp_sales_mst with process_status = 'E' and retry_count + 1.
        Calling this procedure again with the same batch_id retries only those.
    */
    RETURN 0;
END;
GO
