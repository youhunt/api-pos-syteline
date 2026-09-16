/* =============================================================================
   SMK069 - Patch 25 Rev.2 - Canonical Cust PO linkage
   -----------------------------------------------------------------------------
   Date    : 2026-09-16
   Objects : dbo.SMK069ProcessCustomerOrderSp
             dbo.SMK069ProcessBatchCustomerOrdersSp
   Depends : Patch 24 Rev.3+
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY

   FINAL DECISION
   --------------
   - cust_po is the canonical downstream business/process key.
   - Legacy R... source co_num is no longer passed from Batch -> per-order.
   - ue_SMK069_temp_sales_mst.co_num remains the physical staging key before
     success, then becomes the actual generated SyteLine CO number.
   - @SourceCoNum parameter name is retained only for compatibility. New callers
     pass cust_po in that parameter; a legacy direct R... retry can still resolve
     once to cust_po and then all staging reads/updates use cust_po.

   One executable batch; NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    THROW 510250, N'[PATCH-25] dbo.ue_SMK069_temp_sales_mst tidak ditemukan.', 1;
IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'cust_po') IS NULL
    THROW 510251, N'[PATCH-25] Kolom staging cust_po tidak ditemukan.', 1;

DECLARE
    @Lf NCHAR(1) = NCHAR(10),
    @Old NVARCHAR(MAX),
    @New NVARCHAR(MAX),
    @Count INT;

/* ============================================================================
   A. Per-order processor: resolve compatibility input -> canonical cust_po.
   ============================================================================ */
DECLARE
    @ProcId INT = OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp', N'P'),
    @Definition NVARCHAR(MAX);

IF @ProcId IS NULL
    THROW 510252, N'[PATCH-25] dbo.SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);
IF NULLIF(@Definition, N'') IS NULL
    THROW 510253, N'[PATCH-25] Definition ProcessCustomerOrder tidak dapat dibaca.', 1;
SET @Definition = REPLACE(REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

IF CHARINDEX(N'PATCH-24: PYYMMDD### final CO number', @Definition) = 0
    THROW 510254, N'[PATCH-25] Patch 24 belum terpasang. Apply Patch 24 terlebih dahulu.', 1;
IF CHARINDEX(N'@CustPo                  NVARCHAR(100)', @Definition) = 0
    THROW 510255, N'[PATCH-25] Patch 21 business Cust PO mapping belum terpasang.', 1;

IF CHARINDEX(N'PATCH-25: canonical cust_po staging selector', @Definition) = 0
BEGIN
    /* Business Cust PO can be longer than CoNumType. */
    IF CHARINDEX(N'@SourceCoNum   CoNumType,', @Definition) > 0
        SET @Definition = REPLACE
        (
            @Definition,
            N'@SourceCoNum   CoNumType,',
            N'@SourceCoNum   NVARCHAR(100),'
        );

    /* Replace the old mandatory co_num lookup with one compatibility resolver. */
    SET @Old =
          N'        IF NULLIF(@SourceCoNum, N'''') IS NULL' + @Lf
        + N'            THROW 50002, N''Source/POS co_num wajib diisi.'', 1;' + @Lf + @Lf
        + N'        IF NOT EXISTS' + @Lf
        + N'        (' + @Lf
        + N'            SELECT 1' + @Lf
        + N'            FROM dbo.ue_SMK069_temp_sales_mst WITH (UPDLOCK, HOLDLOCK)' + @Lf
        + N'            WHERE SiteRef = @SiteRef' + @Lf
        + N'              AND LTRIM(RTRIM(co_num)) = @SourceCoNum' + @Lf
        + N'        )' + @Lf
        + N'            THROW 50003, N''Data staging untuk SiteRef dan source co_num tersebut tidak ditemukan.'', 1;';

    SET @New =
          N'        IF NULLIF(@SourceCoNum, N'''') IS NULL' + @Lf
        + N'            THROW 50002, N''Cust PO wajib diisi.'', 1;' + @Lf + @Lf
        + N'        /* PATCH-25: canonical cust_po staging selector */' + @Lf
        + N'        SELECT TOP (1)' + @Lf
        + N'            @CustPo = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))' + @Lf
        + N'        FROM dbo.ue_SMK069_temp_sales_mst AS t WITH (UPDLOCK, HOLDLOCK)' + @Lf
        + N'        WHERE t.SiteRef = @SiteRef' + @Lf
        + N'          AND' + @Lf
        + N'          (' + @Lf
        + N'              LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) = @SourceCoNum' + @Lf
        + N'              OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.co_num))) = @SourceCoNum' + @Lf
        + N'          )' + @Lf
        + N'        ORDER BY' + @Lf
        + N'            CASE' + @Lf
        + N'                WHEN LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) = @SourceCoNum THEN 0' + @Lf
        + N'                ELSE 1' + @Lf
        + N'            END,' + @Lf
        + N'            t.co_line;' + @Lf + @Lf
        + N'        IF NULLIF(@CustPo, N'''') IS NULL' + @Lf
        + N'            THROW 50003, N''Data staging untuk Cust PO tersebut tidak ditemukan.'', 1;';

    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510256, N'[PATCH-25] Anchor resolver source key tidak ditemukan tepat satu kali.', 1;
    SET @Definition = REPLACE(@Definition, @Old, @New);

    /* All staging reads/updates after resolver use cust_po. */
    SET @Definition = REPLACE
    (
        @Definition,
        N'LTRIM(RTRIM(s.co_num)) = @SourceCoNum',
        N'LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo'
    );
    SET @Definition = REPLACE
    (
        @Definition,
        N'LTRIM(RTRIM(co_num)) = @SourceCoNum',
        N'LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo'
    );
    SET @Definition = REPLACE
    (
        @Definition,
        N'LTRIM(RTRIM(CONVERT(NVARCHAR(60), co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @SourceCoNum)))',
        N'LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) = @CustPo'
    );
    SET @Definition = REPLACE
    (
        @Definition,
        N'LTRIM(RTRIM(CONVERT(NVARCHAR(60), s.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @SourceCoNum)))',
        N'LTRIM(RTRIM(CONVERT(NVARCHAR(100), s.cust_po))) = @CustPo'
    );

    SET @Definition = REPLACE(@Definition, N'Satu source co_num hanya boleh', N'Satu Cust PO hanya boleh');
    SET @Definition = REPLACE(@Definition, N'Source order sudah memiliki Customer Order', N'Cust PO sudah memiliki Customer Order');

    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
    BEGIN
        SET @Definition = REPLACE(@Definition,
            N'CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
        SET @Definition = REPLACE(@Definition,
            N'CREATE PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
        SET @Definition = REPLACE(@Definition,
            N'CREATE   PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
    END;

    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
        THROW 510257, N'[PATCH-25] Header ProcessCustomerOrder tidak dapat dinormalisasi.', 1;

    EXEC sys.sp_executesql @Definition;
END;

/* ============================================================================
   B. Batch processor: cursor and per-order call use cust_po only.
   ============================================================================ */
DECLARE
    @BatchProcId INT = OBJECT_ID(N'dbo.SMK069ProcessBatchCustomerOrdersSp', N'P'),
    @BatchDef NVARCHAR(MAX);

IF @BatchProcId IS NULL
    THROW 510258, N'[PATCH-25] dbo.SMK069ProcessBatchCustomerOrdersSp tidak ditemukan.', 1;

SET @BatchDef = OBJECT_DEFINITION(@BatchProcId);
IF NULLIF(@BatchDef, N'') IS NULL
    THROW 510259, N'[PATCH-25] Definition ProcessBatch tidak dapat dibaca.', 1;
SET @BatchDef = REPLACE(REPLACE(@BatchDef, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

IF CHARINDEX(N'PATCH-25: batch calls per-order by cust_po', @BatchDef) = 0
BEGIN
    /* co_num is no longer required by business BatchOrders discovery. */
    SET @BatchDef = REPLACE
    (
        @BatchDef,
        N'          AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num))), N'''') IS NOT NULL' + @Lf,
        N''
    );

    /* Patch-24 tenant version: 3-column cursor. */
    SET @Old =
          N'    DECLARE OrderCursor CURSOR LOCAL FAST_FORWARD FOR' + @Lf
        + N'        SELECT SiteRef, co_num, cust_seq' + @Lf
        + N'        FROM #SMK069BatchOrders' + @Lf
        + N'        WHERE is_pending = 1' + @Lf
        + N'        ORDER BY co_num;';
    SET @New =
          N'    /* PATCH-25: batch calls per-order by cust_po */' + @Lf
        + N'    DECLARE OrderCursor CURSOR LOCAL FAST_FORWARD FOR' + @Lf
        + N'        SELECT SiteRef, cust_po, cust_seq' + @Lf
        + N'        FROM #SMK069BatchOrders' + @Lf
        + N'        WHERE is_pending = 1' + @Lf
        + N'        ORDER BY cust_po;';

    IF CHARINDEX(@Old, @BatchDef) > 0
        SET @BatchDef = REPLACE(@BatchDef, @Old, @New);
    ELSE
    BEGIN
        /* Intermediate canonical version: 4-column cursor. */
        SET @Old =
              N'    DECLARE OrderCursor CURSOR LOCAL FAST_FORWARD FOR' + @Lf
            + N'        SELECT SiteRef, co_num, cust_po, cust_seq' + @Lf
            + N'        FROM #SMK069BatchOrders' + @Lf
            + N'        WHERE is_pending = 1' + @Lf
            + N'        ORDER BY cust_po;';
        SET @New =
              N'    /* PATCH-25: batch calls per-order by cust_po */' + @Lf
            + N'    DECLARE OrderCursor CURSOR LOCAL FAST_FORWARD FOR' + @Lf
            + N'        SELECT SiteRef, cust_po, cust_seq' + @Lf
            + N'        FROM #SMK069BatchOrders' + @Lf
            + N'        WHERE is_pending = 1' + @Lf
            + N'        ORDER BY cust_po;';
        IF CHARINDEX(@Old, @BatchDef) > 0
            SET @BatchDef = REPLACE(@BatchDef, @Old, @New);
    END;

    /* Ensure one CustPo variable, remove CoNum cursor variable. */
    IF CHARINDEX(N'        @CoNum         CoNumType,' + @Lf, @BatchDef) > 0
        SET @BatchDef = REPLACE
        (
            @BatchDef,
            N'        @CoNum         CoNumType,' + @Lf,
            N''
        );

    IF CHARINDEX(N'        @CustPo        NVARCHAR(100),' + @Lf, @BatchDef) = 0
        SET @BatchDef = REPLACE
        (
            @BatchDef,
            N'        @SiteRef       SiteType,' + @Lf,
            N'        @SiteRef       SiteType,' + @Lf
            + N'        @CustPo        NVARCHAR(100),' + @Lf
        );

    SET @BatchDef = REPLACE
    (
        @BatchDef,
        N'FETCH NEXT FROM OrderCursor INTO @SiteRef, @CoNum, @CustSeq;',
        N'FETCH NEXT FROM OrderCursor INTO @SiteRef, @CustPo, @CustSeq;'
    );
    SET @BatchDef = REPLACE
    (
        @BatchDef,
        N'FETCH NEXT FROM OrderCursor INTO @SiteRef, @CoNum, @CustPo, @CustSeq;',
        N'FETCH NEXT FROM OrderCursor INTO @SiteRef, @CustPo, @CustSeq;'
    );
    SET @BatchDef = REPLACE
    (
        @BatchDef,
        N'            @SourceCoNum  = @CoNum,',
        N'            @SourceCoNum  = @CustPo,'
    );

    /* Patch-24 error detail had to look CustPo up via old co_num; no longer. */
    SET @BatchDef = REPLACE
    (
        @BatchDef,
        N'COALESCE' + @Lf
        + N'                  (' + @Lf
        + N'                      (SELECT TOP (1) cust_po FROM #SMK069BatchOrders WHERE co_num = @CoNum),' + @Lf
        + N'                      N''<NULL>''' + @Lf
        + N'                  )',
        N'COALESCE(@CustPo, N''<NULL>'')'
    );

    SET @BatchDef = REPLACE
    (
        @BatchDef,
        N'pastikan cust_po/co_num mapping dan row staging tersedia.',
        N'pastikan cust_po terisi dan row staging tersedia.'
    );
    SET @BatchDef = REPLACE
    (
        @BatchDef,
        N'pastikan co_num terisi dan row staging tersedia.',
        N'pastikan cust_po terisi dan row staging tersedia.'
    );

    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp', @BatchDef) = 0
    BEGIN
        SET @BatchDef = REPLACE(@BatchDef,
            N'CREATE OR ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp');
        SET @BatchDef = REPLACE(@BatchDef,
            N'CREATE PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp');
        SET @BatchDef = REPLACE(@BatchDef,
            N'CREATE   PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp');
    END;

    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp', @BatchDef) = 0
        THROW 510260, N'[PATCH-25] Header ProcessBatch tidak dapat dinormalisasi.', 1;

    EXEC sys.sp_executesql @BatchDef;
END;

/* Post-checks. */
SET @Definition = OBJECT_DEFINITION(@ProcId);
IF CHARINDEX(N'PATCH-25: canonical cust_po staging selector', COALESCE(@Definition, N'')) = 0
    THROW 510261, N'[PATCH-25] Post-check canonical cust_po selector gagal.', 1;
IF CHARINDEX(N'LTRIM(RTRIM(s.co_num)) = @SourceCoNum', COALESCE(@Definition, N'')) > 0
    THROW 510262, N'[PATCH-25] Masih ada staging selector s.co_num legacy.', 1;
IF CHARINDEX(N'LTRIM(RTRIM(co_num)) = @SourceCoNum', COALESCE(@Definition, N'')) > 0
    THROW 510263, N'[PATCH-25] Masih ada staging selector co_num legacy.', 1;

SET @BatchDef = OBJECT_DEFINITION(@BatchProcId);
IF CHARINDEX(N'PATCH-25: batch calls per-order by cust_po', COALESCE(@BatchDef, N'')) = 0
    THROW 510264, N'[PATCH-25] Post-check batch Cust PO cursor gagal.', 1;
IF CHARINDEX(N'@SourceCoNum  = @CustPo', COALESCE(@BatchDef, N'')) = 0
    THROW 510265, N'[PATCH-25] Batch masih belum mengirim Cust PO ke per-order processor.', 1;

PRINT N'[PATCH-25] SUCCESS - downstream Auto CO canonical memakai cust_po; legacy R... hanya compatibility input.';