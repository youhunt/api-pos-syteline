/* =============================================================================
   SMK069 - Patch 27 - Peak Season flag plumbing
   -----------------------------------------------------------------------------
   Date    : 2026-09-21
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY

   Business requirement:
     - payload field  : is_peak_season
     - SQL type       : INT
     - default        : 0
     - semantics      : 1 = Peak Season, 0 = Normal
     - Error Processing form: read-only checkbox beside CustPo
     - CSV form             : read-only checkbox beside CustPo

   This patch:
     1. Adds is_peak_season to inbound and temp staging.
     2. Adds a supporting is_peak_season column to CSV upload detail so the
        CSV test console can display/pass the same flag.
     3. Redeploys canonical Receive to copy payload is_peak_season into inbound
        and temp rows after Core receive/validate.
     4. Redeploys canonical CSV runner so CSV JSON contains is_peak_season.
     5. Redeploys canonical CSV parser so optional CSV header is_peak_season
        (also accepts typo alias is_peak_seson) defaults to 0 and validates 0/1.

   IMPORTANT:
     - This patch DOES NOT change POS-108 quantity-multiple business logic yet.
     - ue_SMK069_pos_sales_inbound_mapping_view still needs to expose
       is_peak_season. Its tenant definition is not stored in the repository, so
       it is deliberately not guessed/rewritten here.

   Apply Database compatible: one executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    THROW 510270, N'[PATCH-27] inbound table tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    THROW 510271, N'[PATCH-27] temp sales table tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst', N'U') IS NULL
    THROW 510272, N'[PATCH-27] CSV upload detail table tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'is_peak_season') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_sales_inbound_mst
        ADD is_peak_season INT NOT NULL
            CONSTRAINT DF_ue_SMK069_pos_sales_inbound_is_peak_season DEFAULT (0) WITH VALUES;
END;

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'is_peak_season') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_temp_sales_mst
        ADD is_peak_season INT NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_is_peak_season DEFAULT (0) WITH VALUES;
END;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'is_peak_season') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_csv_upload_mst
        ADD is_peak_season INT NOT NULL
            CONSTRAINT DF_ue_SMK069_pos_csv_upload_is_peak_season DEFAULT (0) WITH VALUES;
END;

/* Redeploy current canonical public Receive. */
DECLARE @Patch27ReceiveSql NVARCHAR(MAX) = N'';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'/* =============================================================================
   Canonical source: dbo.SMK069ReceivePosSalesJsonSp
   Receive -> Validate -> Quantity Multiple Check -> Blanket Customer Order
   -----------------------------------------------------------------------------
   Date    : 2026-09-21
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
   - Quantity-multiple validation runs after Core receive/validate but BEFORE CO
     processing. A fractional converted base quantity rejects the whole cust_po.
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
    SET @BatchId = NULLIF(LTRIM(RTRIM(@BatchId)), N'''');
    SET @ReceivedBy = COALESCE
    (
        NULLIF(LTRIM(RTRIM(@ReceivedBy)), N''''),
        CONVERT(NVARCHAR(128), SUSER_SNAME())
    );

    SET @ReceivedRows    = 0;
    SET @TotalOrders     = 0;
    SET @ValidOrders     = 0;
    SET @ErrorOrders     = 0';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N';
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
        @CodePos           INT            = 0,
        @QtyRejectedOrders INT            = 0;

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
            is_peak_season INT           ''$.is_peak_season''
        ) AS p
        WHERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), p.cust_po))), N'''') IS NOT NULL
          AND ISNULL(p.coline, 0) > 0;

        UPDATE i
        SET i.is_peak_season = p.is_peak_season
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN
        (
            SELECT cust_po, co_line, MAX(is_peak_season) AS is_peak_season
            FROM @PeakSeasonPayl';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'oad
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
       1B. Quantity multiple validation (POS-108)

       Business-supplied rule:
         converted base qty = SMK030_UomConvQty2
         (
             qty_ordered,
             Getumcf(u_m, mapped item, '''', ''''),
             ''To Base''
         )

       Fractional base qty means the ordered quantity is not on an allowed
       multiple. The ENTIRE cust_po is rejected before Customer Order creation.
       ========================================================================= */
    IF ISNULL(@TransferredRows, 0) > 0
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
            SELECT @QtyRejectedOrd';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'ers = COUNT(DISTINCT cust_po)
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
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
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
';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'                  AND i.batch_id       = @BatchId
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
            @ProcessedOrders = @ProcessedOrders  OUTPUT,
            @ProcessErrors   = @ProcessErrors    OUTPUT,
            @SkippedOrders   = @SkippedOrders    OUTPUT,
            @FirstErrorCode  = @ProcessErrorCode OUTPUT,
            @ProcessDetail   = @ProcessDetail    OUTPUT,
            @CreatedCoNums   = @CreatedCoNums    OUTPUT;

        /* Rejected quantity POs are not "already processed" skips. */
        IF @QtyRejectedOrders > 0 AND @SkippedOrders > 0
            SET @SkippedOrders =
                CASE
                    WHEN @SkippedOrders >= @QtyRejectedOrders
                    THEN @SkippedOrders - @QtyRejectedOrders
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
                    ';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'         (
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

            IF EXISTS
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
      ';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'                              + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'', u_m='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))), N''''), N''<kosong>'')
                                    + N'', order_date='' + COALESCE(CONVERT(NVARCHAR(10), e.order_date, 23), N''<kosong>'')
                                    + N'']''
                                WHEN e.validation_msg LIKE N''%Warehouse%''
                                THEN
                                    N''Warehouse tidak valid di Infor''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', whse='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.whse))), N''''), N''<kosong>'')
                                    + N'']''
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
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), ';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'N''''), N''<kosong>'')
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
                     ';
SET @Patch27ReceiveSql = @Patch27ReceiveSql + N'ISNULL(@ErrorOrders, 0) > 0
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
       ========================================================================= */
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
EXEC sys.sp_executesql @Patch27ReceiveSql;

/* Redeploy current canonical CSV runner. */
DECLARE @Patch27CsvRunnerSql NVARCHAR(MAX) = N'';
SET @Patch27CsvRunnerSql = @Patch27CsvRunnerSql + N'/* =============================================================================
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
SET @Patch27CsvRunnerSql = @Patch27CsvRunnerSql + N'    WHERE SiteRef = @Site
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
SET @Patch27CsvRunnerSql = @Patch27CsvRunnerSql + N'    WHERE d.SiteRef = @Site AND d.batch_id = @BatchId
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
SET @Patch27CsvRunnerSql = @Patch27CsvRunnerSql + N'            validation_error_orders = ISNULL(@ValidationErrorOrders, 0),
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
EXEC sys.sp_executesql @Patch27CsvRunnerSql;

/* Redeploy current canonical CSV parser. */
DECLARE @Patch27CsvParserSql NVARCHAR(MAX) = N'';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N'CREATE OR ALTER PROCEDURE dbo.SMK069ImportCsvFileSp
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
    SET @CsvText = REPLACE(@CsvText, NCHAR(13), NCHAR(10));

    IF NULLIF(LTRIM(RTRIM(REPLACE(@CsvText, NCHAR(10), N''''))), N'''') IS NULL
    BEGIN
        SET @Infobar = N''[POS-402] Isi CSV kosong.'';
        ';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N'RETURN 16;
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
            SET @CursorPos = LEN(@CsvText + N''#'');
        END
        ELSE
        BEGIN
            SET @Line = SUBSTRING(@CsvText, @CursorPos, @NextLf - @CursorPos);
            SET @CursorPos = @NextLf + 1';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N';
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
            ) AS n;

            IF EXISTS
            (
                SELECT canonical_name
                FROM @Header
                WHERE canonical_name IS NOT NULL
    ';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N'            GROUP BY canonical_name
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
            @RawItem      = MAX(CASE WHEN h.canonical_name = N''item''         THEN f.field_value END),
            @RawQty       = MAX(CASE WHEN h.canonical_name = N''qty_ordered''  THEN f.field_value END),
            @RawUnitPrice = MAX(CAS';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N'E WHEN h.canonical_name = N''unit_price''   THEN f.field_value END),
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
        IF @RawQty IS NULL
            SET @Message += N''[POS-008] qty_ordered kosong; '';
        ELSE IF @QtyOrdered IS NULL OR @QtyOrdered <= 0
            SET @Mess';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N'age += N''[POS-008] qty_ordered harus angka > 0; '';
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

        INSERT INTO dbo.ue_SMK069_pos_csv_upload_mst
        (
            batch_id,
            source_system,
            file_name,
            row_no,
            custnum,
            order_date,
            cu';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N'st_po,
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
                  OR NULLIF(LTRIM(RTRIM(whse)), N'''') IS NULL
                  OR NULLIF(LTRIM(RTRIM(u_m)), N'''') IS NULL
              )
        )
        BEGIN
            DECLARE @MissingV2Field NVARCHAR(100);

        ';
SET @Patch27CsvParserSql = @Patch27CsvParserSql + N'    SELECT TOP (1)
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
EXEC sys.sp_executesql @Patch27CsvParserSql;

/* Post-checks. */
IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'is_peak_season') IS NULL
    THROW 510273, N'[PATCH-27] inbound is_peak_season gagal dibuat.', 1;
IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'is_peak_season') IS NULL
    THROW 510274, N'[PATCH-27] temp is_peak_season gagal dibuat.', 1;
IF COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'is_peak_season') IS NULL
    THROW 510275, N'[PATCH-27] CSV upload is_peak_season gagal dibuat.', 1;

IF CHARINDEX(N'PATCH-27: propagate is_peak_season',
             COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N'')) = 0
    THROW 510276, N'[PATCH-27] Receive belum mem-persist is_peak_season.', 1;

IF CHARINDEX(N'PATCH-27: peak season CSV payload',
             COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp')), N'')) = 0
    THROW 510277, N'[PATCH-27] CSV runner belum membawa is_peak_season.', 1;

IF CHARINDEX(N'is_peak_seson',
             COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ImportCsvFileSp')), N'')) = 0
    THROW 510278, N'[PATCH-27] CSV parser peak-season belum terpasang.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'V') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view')
         AND name = N'is_peak_season'
   )
BEGIN
    PRINT N'[PATCH-27] NOTE - mapping view belum expose is_peak_season; update view setelah definition tenant diaudit.';
END;

PRINT N'[PATCH-27] SUCCESS - is_peak_season tersedia di inbound/temp/CSV detail dan payload plumbing aktif.';
