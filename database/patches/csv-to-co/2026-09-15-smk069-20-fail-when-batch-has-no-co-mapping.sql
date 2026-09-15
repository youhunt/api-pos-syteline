/* =============================================================================
   SMK069 - Patch 20 - Fail explicitly when Receive transferred rows but
                        ProcessBatch cannot resolve any CO order mapping
   -----------------------------------------------------------------------------
   Date    : 2026-09-15
   Object  : dbo.SMK069ProcessBatchCustomerOrdersSp

   WHY
   ---
   Auto-CO can appear to "do nothing" when Receive/Validate transfers rows but
   ue_SMK069_pos_sales_inbound_mapping_view returns no row with non-empty co_num
   for the same SiteRef + SourceSystem + BatchId.

   Before this patch that condition returned:
       ProcessedOrders = 0
       ProcessErrors   = 0
       SkippedOrders   = 0
   so the public receive wrapper could report success even though no CO was
   created. This patch turns that silent no-op into POS-302 so the actual mapping
   problem is visible to UAT/API callers.

   APPLY DATABASE
   --------------
   - One executable batch.
   - No GO.
   - No table/schema change.
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

    ;WITH BatchOrders AS
    (
        SELECT DISTINCT
            v.SiteRef                                             AS SiteRef,
            LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num)))         AS co_num,
            v.cust_seq                                            AS cust_seq
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

    /* -------------------------------------------------------------------------
       Hardening: transferred rows with zero order mapping must never be silent.
       The caller will surface @FirstErrorCode/@ProcessDetail in its API response.
       ------------------------------------------------------------------------- */
    IF NOT EXISTS (SELECT 1 FROM #SMK069BatchOrders)
    BEGIN
        SET @ProcessErrors  = 1;
        SET @FirstErrorCode = N'POS-302';
        SET @ProcessDetail  = LEFT
        (
            N'[POS-302] Auto CO tidak menemukan order mapping untuk batch. '
            + N'Periksa dbo.ue_SMK069_pos_sales_inbound_mapping_view: SiteRef='
            + COALESCE(CONVERT(NVARCHAR(16), @Site), N'<NULL>')
            + N'; SourceSystem=' + COALESCE(@SourceSystem, N'<NULL>')
            + N'; BatchId=' + COALESCE(@BatchId, N'<NULL>')
            + N'; pastikan co_num terisi dan row staging tersedia.',
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
