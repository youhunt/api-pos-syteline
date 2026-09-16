/* =============================================================================
   SMK069 - Patch 24 - Final CO number in temp + Cust PO linkage + Release Date
   -----------------------------------------------------------------------------
   Date    : 2026-09-16
   Objects : dbo.SMK069ProcessCustomerOrderSp
             dbo.SMK069ProcessBatchCustomerOrdersSp
             dbo.ue_SMK069_temp_sales_mst (DATA ONLY; no new column)
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY

   BUSINESS DECISION - 16 Sep 2026
   --------------------------------
   1. New SyteLine CO number format:
          P + YY + MM + DD + 001
      Example for 16 Sep 2026:
          P260916001
      Running number is 3 digits and resets by date because the date is part
      of the prefix.

   2. ue_SMK069_temp_sales_mst.co_num must become the ACTUAL SyteLine CO number
      after successful processing. Do not add another target-CO field just for
      this purpose.

   3. Business linkage across the integration is cust_po. The generated R...
      source key is no longer the business identifier. It remains only as a
      transient pre-process staging selector where required by the legacy Core.

   4. coitem_mst.release_date must equal co_mst.order_date / staging order_date.

   IMPORTANT
   ---------
   - Existing standard Customer Orders are NOT renumbered.
   - Existing Processed staging rows are safely relinked to the already-created
     Blanket CO only when SiteRef + customer + cust_po resolves to exactly one CO.
   - New successful rows replace staging co_num with the newly generated CO.
   - Failed/unprocessed staging rows keep the transient source co_num so they can
     still be retried safely.
   - Patch 23 (syteline_co_num column approach) is superseded and is NOT required.
   - One executable batch; NO GO (Infor Apply Database compatible).
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    THROW 510240, N'[PATCH-24] dbo.ue_SMK069_temp_sales_mst tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'cust_po') IS NULL
    THROW 510241, N'[PATCH-24] Kolom staging cust_po tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.coitem_mst', N'release_date') IS NULL
    THROW 510242, N'[PATCH-24] Kolom dbo.coitem_mst.release_date tidak ditemukan.', 1;

DECLARE @CoNumLen INT;
SELECT @CoNumLen = CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'dbo'
  AND TABLE_NAME = N'co_mst'
  AND COLUMN_NAME = N'co_num';

IF ISNULL(@CoNumLen, 0) < 10
    THROW 510243, N'[PATCH-24] co_mst.co_num lebih pendek dari 10 karakter; format PYYMMDD### tidak aman.', 1;

SELECT @CoNumLen = CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'dbo'
  AND TABLE_NAME = N'ue_SMK069_temp_sales_mst'
  AND COLUMN_NAME = N'co_num';

IF ISNULL(@CoNumLen, 0) < 10
    THROW 510244, N'[PATCH-24] staging co_num lebih pendek dari 10 karakter; format PYYMMDD### tidak aman.', 1;

/* ============================================================================
   A. Patch per-order processor
   ============================================================================ */
DECLARE
    @ProcName   SYSNAME       = N'dbo.SMK069ProcessCustomerOrderSp',
    @ProcId     INT,
    @Definition NVARCHAR(MAX),
    @Lf         NCHAR(1)      = NCHAR(10),
    @Old        NVARCHAR(MAX),
    @New        NVARCHAR(MAX),
    @Count      INT;

SET @ProcId = OBJECT_ID(@ProcName, N'P');
IF @ProcId IS NULL
    THROW 510245, N'[PATCH-24] dbo.SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);
IF NULLIF(@Definition, N'') IS NULL
    THROW 510246, N'[PATCH-24] Definition SMK069ProcessCustomerOrderSp tidak dapat dibaca.', 1;

SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

IF CHARINDEX(N'PATCH-24: PYYMMDD### final CO number', @Definition) = 0
BEGIN
    /* 1. Number format: COYYMM#### -> PYYMMDD###. */
    SET @Old =
          N'        SET @KeyPrefix = N''CO'' + CONVERT(CHAR(4), @OrderDate, 12);' + @Lf
        + N'        SET @NumberLength = 4;';
    SET @New =
          N'        /* PATCH-24: PYYMMDD### final CO number */' + @Lf
        + N'        SET @KeyPrefix = N''P'' + CONVERT(CHAR(6), @OrderDate, 12);' + @Lf
        + N'        SET @NumberLength = 3;';
    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510247, N'[PATCH-24] Anchor format CO lama tidak ditemukan tepat satu kali.', 1;
    SET @Definition = REPLACE(@Definition, @Old, @New);

    /* 2. New coitem rows: release_date = order_date. */
    SET @Old =
          N'            u_m,' + @Lf
        + N'            due_date,' + @Lf
        + N'            price,';
    SET @New =
          N'            u_m,' + @Lf
        + N'            due_date,' + @Lf
        + N'            release_date,' + @Lf
        + N'            price,';
    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510248, N'[PATCH-24] Anchor kolom coitem release_date tidak ditemukan tepat satu kali.', 1;
    SET @Definition = REPLACE(@Definition, @Old, @New);

    SET @Old =
          N'            COALESCE(s.due_date, @OrderDate),' + @Lf
        + N'            s.unit_price,';
    SET @New =
          N'            COALESCE(s.due_date, @OrderDate),' + @Lf
        + N'            @OrderDate,' + @Lf
        + N'            s.unit_price,';
    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510249, N'[PATCH-24] Anchor value coitem release_date tidak ditemukan tepat satu kali.', 1;
    SET @Definition = REPLACE(@Definition, @Old, @New);

    /*
       3. Existing matching Blanket: repair release_date and replace the transient
          staging co_num with the actual existing SyteLine CO number.
    */
    SET @Old = N'            SET @CreatedCoNum = @ExistingCoNum;';
    SET @New =
          N'            /* PATCH-24: sync existing CO release date + final staging co_num */' + @Lf
        + N'            UPDATE ci' + @Lf
        + N'            SET ci.release_date = @OrderDate' + @Lf
        + N'            FROM dbo.coitem_mst AS ci' + @Lf
        + N'            WHERE ci.site_ref = @SiteRef' + @Lf
        + N'              AND ci.co_num = @ExistingCoNum' + @Lf
        + N'              AND (ci.release_date IS NULL OR ci.release_date <> @OrderDate);' + @Lf + @Lf
        + N'            IF LTRIM(RTRIM(CONVERT(NVARCHAR(60), @ExistingCoNum))) <> LTRIM(RTRIM(CONVERT(NVARCHAR(60), @SourceCoNum)))' + @Lf
        + N'               AND EXISTS' + @Lf
        + N'               (' + @Lf
        + N'                   SELECT 1' + @Lf
        + N'                   FROM dbo.ue_SMK069_temp_sales_mst AS x' + @Lf
        + N'                   WHERE x.SiteRef = @SiteRef' + @Lf
        + N'                     AND LTRIM(RTRIM(CONVERT(NVARCHAR(60), x.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @ExistingCoNum)))' + @Lf
        + N'               )' + @Lf
        + N'                THROW 50036, N''Target SyteLine CO number sudah dipakai row staging lain.'', 1;' + @Lf + @Lf
        + N'            UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
        + N'            SET' + @Lf
        + N'                co_num = @ExistingCoNum,' + @Lf
        + N'                RecordDate = GETDATE(),' + @Lf
        + N'                UpdatedBy = @ProcessedBy' + @Lf
        + N'            WHERE SiteRef = @SiteRef' + @Lf
        + N'              AND LTRIM(RTRIM(CONVERT(NVARCHAR(60), co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @SourceCoNum)));' + @Lf + @Lf
        + N'            SET @CreatedCoNum = @ExistingCoNum;';
    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510250, N'[PATCH-24] Anchor existing @CreatedCoNum tidak ditemukan tepat satu kali.', 1;
    SET @Definition = REPLACE(@Definition, @Old, @New);

    /* 4. New CO: after successful detail creation, make temp.co_num the final CO. */
    SET @Old =
          N'        WHERE SiteRef = @SiteRef' + @Lf
        + N'          AND LTRIM(RTRIM(co_num)) = @SourceCoNum;' + @Lf + @Lf
        + N'        COMMIT TRANSACTION;' + @Lf + @Lf
        + N'        SET @Success = 1;';
    SET @New =
          N'        WHERE SiteRef = @SiteRef' + @Lf
        + N'          AND LTRIM(RTRIM(co_num)) = @SourceCoNum;' + @Lf + @Lf
        + N'        /* PATCH-24: temp.co_num becomes the actual SyteLine CO number */' + @Lf
        + N'        IF LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))) <> LTRIM(RTRIM(CONVERT(NVARCHAR(60), @SourceCoNum)))' + @Lf
        + N'           AND EXISTS' + @Lf
        + N'           (' + @Lf
        + N'               SELECT 1' + @Lf
        + N'               FROM dbo.ue_SMK069_temp_sales_mst AS x' + @Lf
        + N'               WHERE x.SiteRef = @SiteRef' + @Lf
        + N'                 AND LTRIM(RTRIM(CONVERT(NVARCHAR(60), x.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum)))' + @Lf
        + N'           )' + @Lf
        + N'            THROW 50037, N''Generated SyteLine CO number sudah dipakai row staging lain.'', 1;' + @Lf + @Lf
        + N'        UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
        + N'        SET' + @Lf
        + N'            co_num = @CreatedCoNum,' + @Lf
        + N'            RecordDate = GETDATE(),' + @Lf
        + N'            UpdatedBy = @ProcessedBy' + @Lf
        + N'        WHERE SiteRef = @SiteRef' + @Lf
        + N'          AND LTRIM(RTRIM(CONVERT(NVARCHAR(60), co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @SourceCoNum)));' + @Lf + @Lf
        + N'        COMMIT TRANSACTION;' + @Lf + @Lf
        + N'        SET @Success = 1;';
    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510251, N'[PATCH-24] Anchor final staging update tidak ditemukan tepat satu kali.', 1;
    SET @Definition = REPLACE(@Definition, @Old, @New);

    /* 5. Do not expose the legacy R... selector in the success message. */
    SET @Old =
          N'        SET @Infobar = N''Customer Order ''' + @Lf
        + N'                     + LTRIM(RTRIM(@CreatedCoNum))' + @Lf
        + N'                     + N'' berhasil dibuat dari source order ''' + @Lf
        + N'                     + @SourceCoNum' + @Lf
        + N'                     + N''.'';';
    SET @New =
          N'        SET @Infobar = N''Customer Order ''' + @Lf
        + N'                     + LTRIM(RTRIM(@CreatedCoNum))' + @Lf
        + N'                     + N'' berhasil dibuat untuk Cust PO ''' + @Lf
        + N'                     + @CustPo' + @Lf
        + N'                     + N''.'';';
    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510252, N'[PATCH-24] Anchor success Infobar tidak ditemukan tepat satu kali.', 1;
    SET @Definition = REPLACE(@Definition, @Old, @New);

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
        THROW 510253, N'[PATCH-24] Header ProcessCustomerOrder tidak dapat dinormalisasi.', 1;

    EXEC sys.sp_executesql @Definition;
END;

/* ============================================================================
   B. Patch batch processor so the BUSINESS pending match follows cust_po.
      Legacy co_num is retained only as the transient selector passed into the
      existing per-order procedure until the successful row is renamed.
   ============================================================================ */
DECLARE
    @BatchProcName SYSNAME = N'dbo.SMK069ProcessBatchCustomerOrdersSp',
    @BatchProcId INT,
    @BatchDef NVARCHAR(MAX);

SET @BatchProcId = OBJECT_ID(@BatchProcName, N'P');
IF @BatchProcId IS NULL
    THROW 510254, N'[PATCH-24] dbo.SMK069ProcessBatchCustomerOrdersSp tidak ditemukan.', 1;

SET @BatchDef = OBJECT_DEFINITION(@BatchProcId);
IF NULLIF(@BatchDef, N'') IS NULL
    THROW 510255, N'[PATCH-24] Definition SMK069ProcessBatchCustomerOrdersSp tidak dapat dibaca.', 1;

SET @BatchDef = REPLACE(@BatchDef, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @BatchDef = REPLACE(@BatchDef, NCHAR(13), NCHAR(10));

IF CHARINDEX(N'PATCH-24: cust_po business pending linkage', @BatchDef) = 0
BEGIN
    SET @Old =
          N'            v.SiteRef                                             AS SiteRef,' + @Lf
        + N'            LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num)))         AS co_num,' + @Lf
        + N'            v.cust_seq                                            AS cust_seq';
    SET @New =
          N'            v.SiteRef                                             AS SiteRef,' + @Lf
        + N'            LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num)))         AS co_num,' + @Lf
        + N'            LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po)))       AS cust_po,' + @Lf
        + N'            v.cust_seq                                            AS cust_seq';
    SET @Count = (LEN(@BatchDef) - LEN(REPLACE(@BatchDef, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510256, N'[PATCH-24] Anchor BatchOrders select tidak ditemukan tepat satu kali.', 1;
    SET @BatchDef = REPLACE(@BatchDef, @Old, @New);

    SET @Old = N'          AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num))), N'''') IS NOT NULL';
    SET @New =
          @Old + @Lf
        + N'          AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))), N'''') IS NOT NULL';
    SET @Count = (LEN(@BatchDef) - LEN(REPLACE(@BatchDef, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510257, N'[PATCH-24] Anchor filter BatchOrders tidak ditemukan tepat satu kali.', 1;
    SET @BatchDef = REPLACE(@BatchDef, @Old, @New);

    SET @Old =
          N'        b.SiteRef,' + @Lf
        + N'        b.co_num,' + @Lf
        + N'        b.cust_seq,';
    SET @New =
          N'        b.SiteRef,' + @Lf
        + N'        b.co_num,' + @Lf
        + N'        b.cust_po,' + @Lf
        + N'        b.cust_seq,' + @Lf
        + N'        /* PATCH-24: cust_po business pending linkage */';
    SET @Count = (LEN(@BatchDef) - LEN(REPLACE(@BatchDef, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510258, N'[PATCH-24] Anchor #BatchOrders columns tidak ditemukan tepat satu kali.', 1;
    SET @BatchDef = REPLACE(@BatchDef, @Old, @New);

    SET @Old =
          N'                      AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))))' + @Lf
        + N'                              COLLATE DATABASE_DEFAULT' + @Lf
        + N'                          = UPPER(b.co_num) COLLATE DATABASE_DEFAULT';
    SET @New =
          N'                      AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))))' + @Lf
        + N'                              COLLATE DATABASE_DEFAULT' + @Lf
        + N'                          = UPPER(b.cust_po) COLLATE DATABASE_DEFAULT';
    SET @Count = (LEN(@BatchDef) - LEN(REPLACE(@BatchDef, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510259, N'[PATCH-24] Anchor pending-match co_num tidak ditemukan tepat satu kali.', 1;
    SET @BatchDef = REPLACE(@BatchDef, @Old, @New);

    SET @Old = N'            + N''; pastikan co_num terisi dan row staging tersedia.'',';
    SET @New = N'            + N''; pastikan cust_po/co_num mapping dan row staging tersedia.'',';
    IF CHARINDEX(@Old, @BatchDef) > 0
        SET @BatchDef = REPLACE(@BatchDef, @Old, @New);

    /* Remove Patch-23 persistence block if it happened to be deployed. */
    IF CHARINDEX(N'            /* PATCH-23: persist generated SyteLine CO number */', @BatchDef) > 0
    BEGIN
        SET @Old =
              N'            /* PATCH-23: persist generated SyteLine CO number */' + @Lf
            + N'            IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))), N'''') IS NOT NULL' + @Lf
            + N'            BEGIN' + @Lf
            + N'                UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
            + N'                SET' + @Lf
            + N'                    syteline_co_num = CONVERT(NVARCHAR(10), @CreatedCoNum),' + @Lf
            + N'                    RecordDate = GETDATE(),' + @Lf
            + N'                    UpdatedBy = @ProcessedBy' + @Lf
            + N'                WHERE SiteRef = @SiteRef' + @Lf
            + N'                  AND LTRIM(RTRIM(co_num)) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CoNum)));' + @Lf
            + N'            END;' + @Lf + @Lf;
        SET @BatchDef = REPLACE(@BatchDef, @Old, N'');
    END;

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
        THROW 510260, N'[PATCH-24] Header ProcessBatch tidak dapat dinormalisasi.', 1;

    EXEC sys.sp_executesql @BatchDef;
END;

/* ============================================================================
   C. Safe historical relink: Processed temp co_num -> actual existing Blanket CO
      using business Cust PO. Existing standard CO numbers are NOT changed.
   ============================================================================ */
;WITH SourceOrders AS
(
    SELECT DISTINCT
        t.SiteRef,
        LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))) AS OldTempCoNum,
        LTRIM(RTRIM(CONVERT(NVARCHAR(40), t.cust_num))) AS CustNum,
        LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) AS CustPo
    FROM dbo.ue_SMK069_temp_sales_mst AS t
    WHERE t.process_status = N'P'
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))), N'') IS NOT NULL
),
Candidates AS
(
    SELECT
        s.SiteRef,
        s.OldTempCoNum,
        c.co_num AS TargetCoNum
    FROM SourceOrders AS s
    INNER JOIN dbo.co_mst AS c
        ON c.site_ref = s.SiteRef
       AND LTRIM(RTRIM(CONVERT(NVARCHAR(40), c.cust_num))) = s.CustNum
       AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_po))) = s.CustPo
       AND c.[type] = N'B'
),
UniqueMap AS
(
    SELECT
        SiteRef,
        OldTempCoNum,
        MIN(TargetCoNum) AS TargetCoNum
    FROM Candidates
    GROUP BY SiteRef, OldTempCoNum
    HAVING COUNT(DISTINCT TargetCoNum) = 1
)
UPDATE t
SET
    t.co_num = u.TargetCoNum,
    t.RecordDate = GETDATE(),
    t.UpdatedBy = SUSER_SNAME()
FROM dbo.ue_SMK069_temp_sales_mst AS t
INNER JOIN UniqueMap AS u
    ON u.SiteRef = t.SiteRef
   AND u.OldTempCoNum = LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num)))
WHERE t.process_status = N'P'
  AND LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))) <> LTRIM(RTRIM(CONVERT(NVARCHAR(60), u.TargetCoNum)))
  AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.ue_SMK069_temp_sales_mst AS x
          WHERE x.SiteRef = t.SiteRef
            AND LTRIM(RTRIM(CONVERT(NVARCHAR(60), x.co_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), u.TargetCoNum)))
            AND x.co_line = t.co_line
            AND x.RowPointer <> t.RowPointer
      );

/* Historical/current matching CO line release date repair. */
UPDATE ci
SET ci.release_date = c.order_date
FROM dbo.coitem_mst AS ci
INNER JOIN dbo.co_mst AS c
    ON c.site_ref = ci.site_ref
   AND c.co_num = ci.co_num
WHERE c.[type] = N'B'
  AND c.order_date IS NOT NULL
  AND (ci.release_date IS NULL OR ci.release_date <> c.order_date)
  AND EXISTS
      (
          SELECT 1
          FROM dbo.ue_SMK069_temp_sales_mst AS t
          WHERE t.SiteRef = c.site_ref
            AND t.process_status = N'P'
            AND LTRIM(RTRIM(CONVERT(NVARCHAR(40), t.cust_num))) = LTRIM(RTRIM(CONVERT(NVARCHAR(40), c.cust_num)))
            AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) = LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_po)))
      );

/* If Patch 23 had already added the column, keep it harmlessly synchronized. */
IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'syteline_co_num') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        UPDATE dbo.ue_SMK069_temp_sales_mst
        SET syteline_co_num = CONVERT(NVARCHAR(10), co_num)
        WHERE process_status = N''P''
          AND (syteline_co_num IS NULL OR syteline_co_num <> CONVERT(NVARCHAR(10), co_num));';
END;

/* Post-checks. */
SET @Definition = OBJECT_DEFINITION(@ProcId);
IF CHARINDEX(N'PATCH-24: PYYMMDD### final CO number', COALESCE(@Definition, N'')) = 0
    THROW 510261, N'[PATCH-24] Post-check format nomor CO gagal.', 1;
IF CHARINDEX(N'            release_date,', COALESCE(@Definition, N'')) = 0
    THROW 510262, N'[PATCH-24] Post-check coitem release_date gagal.', 1;
IF CHARINDEX(N'co_num = @CreatedCoNum', COALESCE(@Definition, N'')) = 0
    THROW 510263, N'[PATCH-24] Post-check final temp.co_num gagal.', 1;

SET @BatchDef = OBJECT_DEFINITION(@BatchProcId);
IF CHARINDEX(N'PATCH-24: cust_po business pending linkage', COALESCE(@BatchDef, N'')) = 0
    THROW 510264, N'[PATCH-24] Post-check cust_po batch linkage gagal.', 1;

PRINT N'[PATCH-24] SUCCESS - CO baru PYYMMDD###, temp.co_num = actual SyteLine CO, linkage bisnis cust_po, release_date = order_date.';