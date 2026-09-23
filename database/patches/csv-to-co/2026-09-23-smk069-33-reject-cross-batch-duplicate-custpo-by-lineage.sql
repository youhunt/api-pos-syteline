/* =============================================================================
   SMK069 - Patch 33 - Reject cross-batch duplicate CustPO using inbound lineage
   -----------------------------------------------------------------------------
   Date    : 2026-09-23
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY
   Object  : dbo.SMK069ReceivePosSalesJsonSp

   TENANT-PROVEN COLUMNS
   ---------------------
   dbo.ue_SMK069_pos_sales_inbound_mst:
     inbound_id
     source_system
     batch_id
     SiteRef
     cust_po
     inbound_status

   No CreateDate/RecordDate assumptions are used.

   BUSINESS RULE
   -------------
   - cust_po is the business idempotency key.
   - For a CustPO that already has a CO, the earliest inbound row with
     inbound_status='T' identifies the original source_system + batch_id.
   - Same original source+batch may replay idempotently.
   - Different/new source or BatchId for the same existing CustPO is rejected
     as POS-204.
   - Other unrelated CustPOs in a multi-order request may still continue.

   Apply Database compatible: one executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp', N'P') IS NULL
    THROW 510330, N'[PATCH-33] dbo.SMK069ReceivePosSalesJsonSp tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.co_mst', N'U') IS NULL
    THROW 510331, N'[PATCH-33] dbo.co_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    THROW 510332, N'[PATCH-33] inbound table tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'inbound_id') IS NULL
 OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'source_system') IS NULL
 OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'batch_id') IS NULL
 OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'cust_po') IS NULL
 OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'inbound_status') IS NULL
    THROW 510333, N'[PATCH-33] schema inbound tidak sesuai requirement lineage.', 1;

/* Redeploy current canonical Receive with proven-lineage duplicate gate. */
DECLARE @Patch33ReceiveSql NVARCHAR(MAX) = N'';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'/* =============================================================================
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
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'
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
        @MappingRejectedOrders  INT            = 0,
        @DuplicateRejectedOrders INT           = 0;

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
        WH';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'ERE NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), p.cust_po))), N'''') IS NOT NULL
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
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i0
            WHERE i0.SiteRef = @Site
        ';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'      AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), i0.cust_po))) = p.cust_po
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
              AND i.batch_id      = @BatchId
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

            SET @ReturnCode = 16';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N';
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
              AND i.source_system  = @SourceSystem
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

            /* Reco';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'mpute public counters after mapping business validation. */
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
           AND ISNULL(ic.Uf_SMK069_is_peak_season, 0) = ISNULL(i.is_peak_season, 0)
        CROSS APPLY
        (
            SELECT CAST
            (
                ISNULL
          ';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'      (
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
                      WHERE q.cust_po = LTRIM(R';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'TRIM(CONVERT(NVARCHAR(100), t.cust_po)))
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
            @ProcessedOrders = @ProcessedOrders  OUTPUT,
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
';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'       OR ISNULL(@ValidOrders, 0) = 0
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
                      e.validation_msg NOT LIKE N''O';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'rder memiliki line lain%''
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
                                    N''Item/CustPO tidak valid berdasarkan ValidationStatus mapping''
                                    + N'' [coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
                                    + N'']''
                                WHEN LEFT(LTRIM(COALESCE(e.validation_msg, N'''')), 9) = N''[POS-204]''
                                THEN
                                    N''CustPO sudah terdaftar pada proses sebelumnya. BatchId baru tidak membuat CustPO menjadi transaksi baru''
                                    + N'' [cust_po='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.cust_po))), N''''), N''<kosong>'')
                                    + N'', coline='' + COALESCE(CONVERT(NVARCHAR(20), e.co_line), N''<kosong>'')
                                    + N'']. Jika transaksi baru gunakan cust_po baru; jika retry gunakan request/batch original tanpa mengubah data.''
   ';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'                             WHEN e.validation_msg LIKE N''%Quantity tidak sesuai kelipatan%''
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
                                    + N'', item='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))), N''''), N''<kosong>'')
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
                                    + N'', custnum='' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), e.cus';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N't_num))), N''''), N''<kosong>'')
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
                  WHEN NULLIF(@CreatedCoNums, N'''') IS NULL THEN N';
SET @Patch33ReceiveSql = @Patch33ReceiveSql + N'''''
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
EXEC sys.sp_executesql @Patch33ReceiveSql;


/* Post-checks. */
DECLARE @Patch33Definition NVARCHAR(MAX) =
    COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N'');

IF CHARINDEX(N'PATCH-33: cross-batch duplicate CustPO using original inbound lineage', @Patch33Definition) = 0
    THROW 510334, N'[PATCH-33] duplicate CustPO gate belum terpasang.', 1;

IF CHARINDEX(N'ORDER BY i0.inbound_id', @Patch33Definition) = 0
    THROW 510335, N'[PATCH-33] original batch lineage belum memakai inbound_id.', 1;

IF CHARINDEX(N'CreateDate', @Patch33Definition) > 0
   AND CHARINDEX(N'PATCH-33: cross-batch duplicate CustPO using original inbound lineage', @Patch33Definition) > 0
    PRINT N'[PATCH-33] NOTE - kata CreateDate mungkin berasal dari logic lain; Patch-33 sendiri tidak menggunakannya.';

PRINT N'[PATCH-33] SUCCESS - existing CustPO pada source/batch baru ditolak sebagai POS-204 memakai inbound_id lineage.';
