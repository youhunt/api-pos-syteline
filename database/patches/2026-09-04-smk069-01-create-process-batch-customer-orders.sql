/* =============================================================================
   SMK069 - Partial Success Enablement, Patch 01 of 03
   -----------------------------------------------------------------------------
   Object   : dbo.SMK069ProcessBatchCustomerOrdersSp        (NEW)
   Date     : 2026-09-04
   Depends  : dbo.SMK069ProcessCustomerOrderSp              (UNCHANGED)
              dbo.ue_SMK069_pos_sales_inbound_mapping_view  (UNCHANGED)
              dbo.ue_SMK069_temp_sales_mst                  (UNCHANGED)

   PURPOSE
   -------
   Shared order-loop extracted from SMK069ReceiveAndProcessPosSalesJsonSp so the
   JSON path and the CSV path run the SAME Process logic instead of two copies.

   It walks every order of one batch and calls the stable
   SMK069ProcessCustomerOrderSp once per order. That procedure already owns its
   own BEGIN TRANSACTION / ROLLBACK and reports failure through @Success = 0
   without throwing, so one failed order never affects the others.

   DIFFERENCE FROM THE OLD INLINE LOOP
   -----------------------------------
   1. Orders already at process_status = 'P' are SKIPPED, not re-processed.
      The old loop re-ran them; because Process is idempotent the data stayed
      correct, but @ProcessedOrders counted pre-existing Customer Orders as
      newly created, so a retry that fixed one order reported ten successes.
   2. The generated co_num values are returned in @CreatedCoNums.
   3. Per-order failures are collected in @ProcessDetail with the first POS-xxx
      code surfaced in @FirstErrorCode.

   TRANSACTION REQUIREMENT
   -----------------------
   The calling IDO method MUST NOT be marked Transactional.
   SMK069ProcessCustomerOrderSp issues an unqualified ROLLBACK TRANSACTION in
   its CATCH block. Under an outer transaction, its inner COMMIT only decrements
   @@TRANCOUNT and the first ROLLBACK discards every order committed earlier in
   the same batch.

   RETURN
   ------
   0  loop completed (inspect @ProcessErrors for business outcome)
   16 invalid input
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp
    @SourceSystem     NVARCHAR(50)   = N'POS',
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

    ----------------------------------------------------------------
    -- ACTIVE SITE CONTEXT (SMK069 Site-Aware Hardening 2026-09-03)
    ----------------------------------------------------------------
    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @SourceSystem = UPPER(LTRIM(RTRIM(@SourceSystem)));
    SET @BatchId      = NULLIF(LTRIM(RTRIM(@BatchId)), N'');
    SET @ProcessedBy  = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ProcessedBy)), N''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ProcessedOrders = 0;
    SET @ProcessErrors   = 0;
    SET @SkippedOrders   = 0;
    SET @FirstErrorCode  = NULL;
    SET @ProcessDetail   = N'';
    SET @CreatedCoNums   = N'';

    IF NULLIF(LTRIM(RTRIM(@Site)), N'') IS NULL
        RETURN 16;

    IF @BatchId IS NULL
        RETURN 16;

    /* =========================================================================
       1. Resolve the orders of this batch, and whether each still needs work.
          co_num is taken from the canonical mapping view, which is where
          Receive published the generated SyteLine number.
       ========================================================================= */
    ;WITH BatchOrders AS
    (
        SELECT DISTINCT
            v.SiteRef                                              AS SiteRef,
            LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num)))          AS co_num,
            v.cust_seq                                             AS cust_seq
        FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
        WHERE v.SiteRef       = @Site
          AND v.source_system = @SourceSystem
          AND v.batch_id      = @BatchId
          AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num))), N'') IS NOT NULL
    )
    SELECT
        b.SiteRef,
        b.co_num,
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
                          = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), b.SiteRef))))
                              COLLATE DATABASE_DEFAULT
                      AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))))
                              COLLATE DATABASE_DEFAULT
                          = UPPER(b.co_num) COLLATE DATABASE_DEFAULT
                      AND t.process_status IN (N'V', N'E')
                )
                THEN 1
                ELSE 0
            END
        ) AS is_pending
    INTO #SMK069BatchOrders
    FROM BatchOrders AS b;

    SELECT @SkippedOrders = COUNT(*)
    FROM #SMK069BatchOrders
    WHERE is_pending = 0;

    /* =========================================================================
       2. Process every pending order independently.
       ========================================================================= */
    DECLARE
        @SiteRef       SiteType,
        @CoNum         CoNumType,
        @CustSeq       CustSeqType,
        @CreatedCoNum  CoNumType,
        @Success       ListYesNoType,
        @Info          InfobarType,
        @InfoText      NVARCHAR(4000),
        @CodePos       INT;

    DECLARE OrderCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT SiteRef, co_num, cust_seq
        FROM #SMK069BatchOrders
        WHERE is_pending = 1
        ORDER BY co_num;

    OPEN OrderCursor;
    FETCH NEXT FROM OrderCursor INTO @SiteRef, @CoNum, @CustSeq;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @CreatedCoNum = NULL;
        SET @Success      = 0;
        SET @Info         = NULL;

        EXEC dbo.SMK069ProcessCustomerOrderSp
            @SiteRef      = @SiteRef,
            @SourceCoNum  = @CoNum,
            @CustSeq      = @CustSeq,
            @ProcessedBy  = @ProcessedBy,
            @CreatedCoNum = @CreatedCoNum OUTPUT,
            @Success      = @Success      OUTPUT,
            @Infobar      = @Info         OUTPUT;

        IF ISNULL(@Success, 0) = 1
        BEGIN
            SET @ProcessedOrders += 1;

            IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))), N'') IS NOT NULL
                SET @CreatedCoNums = LEFT
                (
                    @CreatedCoNums
                    + CASE WHEN NULLIF(@CreatedCoNums, N'') IS NULL THEN N'' ELSE N',' END
                    + LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))),
                    8000
                );
        END
        ELSE
        BEGIN
            SET @ProcessErrors += 1;
            SET @InfoText = COALESCE(CONVERT(NVARCHAR(4000), @Info), N'');

            /* First POS-xxx code seen wins; it becomes the batch result code. */
            IF NULLIF(@FirstErrorCode, N'') IS NULL
            BEGIN
                SET @CodePos = CHARINDEX(N'[POS-', @InfoText);
                IF @CodePos > 0
                   AND SUBSTRING(@InfoText, @CodePos + 8, 1) = N']'
                    SET @FirstErrorCode = SUBSTRING(@InfoText, @CodePos + 1, 7);
            END;

            SET @ProcessDetail = LEFT
            (
                @ProcessDetail
                + CASE WHEN NULLIF(@ProcessDetail, N'') IS NULL THEN N'' ELSE N' | ' END
                + N'CO '
                + COALESCE(CONVERT(NVARCHAR(60), @CoNum), N'<NULL>')
                + N': '
                + COALESCE
                  (
                      NULLIF(LEFT(@InfoText, 1000), N''),
                      N'[POS-301] Process Customer Order gagal.'
                  ),
                2800
            );
        END;

        FETCH NEXT FROM OrderCursor INTO @SiteRef, @CoNum, @CustSeq;
    END;

    CLOSE OrderCursor;
    DEALLOCATE OrderCursor;

    IF @ProcessErrors > 0
        SET @FirstErrorCode = COALESCE(NULLIF(@FirstErrorCode, N''), N'POS-301');

    SET @CreatedCoNums = NULLIF(@CreatedCoNums, N'');
    SET @ProcessDetail = NULLIF(@ProcessDetail, N'');

    DROP TABLE #SMK069BatchOrders;

    RETURN 0;
END;
GO
