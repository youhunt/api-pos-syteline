/* =============================================================================
   SMK069 - Patch 26 - Persist created_co_num in temp staging
   -----------------------------------------------------------------------------
   Date    : 2026-09-16
   Objects : dbo.SMK069ProcessCustomerOrderSp
             dbo.ue_SMK069_temp_sales_mst (data backfill only)
   Depends : Patch 24 + Patch 25
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY

   PURPOSE
   -------
   The Error Processing form has a dedicated SyteLine CO Number property backed
   by ue_SMK069_temp_sales_mst.created_co_num. Auto CO already returns the real
   SyteLine CO in @CreatedCoNum, but that value was not persisted into this
   dedicated staging column.

   Final behavior:
     - existing/idempotent CO path -> created_co_num = @ExistingCoNum
     - newly-created CO path       -> created_co_num = @CreatedCoNum
     - historical Processed rows   -> safe backfill by SiteRef + customer + cust_po

   co_num behavior from Patch 24/25 is preserved.
   One executable batch; NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    THROW 510270, N'[PATCH-26] dbo.ue_SMK069_temp_sales_mst tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'created_co_num') IS NULL
    THROW 510271, N'[PATCH-26] Kolom created_co_num tidak ditemukan pada temp staging.', 1;

DECLARE
    @ProcId INT = OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp', N'P'),
    @Definition NVARCHAR(MAX),
    @Lf NCHAR(1) = NCHAR(10),
    @Old NVARCHAR(MAX),
    @New NVARCHAR(MAX),
    @Count INT;

IF @ProcId IS NULL
    THROW 510272, N'[PATCH-26] dbo.SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);
IF NULLIF(@Definition, N'') IS NULL
    THROW 510273, N'[PATCH-26] Definition SMK069ProcessCustomerOrderSp tidak dapat dibaca.', 1;

SET @Definition = REPLACE(REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

IF CHARINDEX(N'PATCH-25: canonical cust_po staging selector', @Definition) = 0
    THROW 510274, N'[PATCH-26] Patch 25 belum terpasang. Apply Patch 25 terlebih dahulu.', 1;

IF CHARINDEX(N'PATCH-26: persist created_co_num', @Definition) = 0
BEGIN
    /* Existing/idempotent Customer Order path. */
    SET @Old =
          N'            UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
        + N'            SET' + @Lf
        + N'                co_num = @ExistingCoNum,' + @Lf
        + N'                process_status = N''P'',';

    SET @New =
          N'            UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
        + N'            SET' + @Lf
        + N'                /* PATCH-26: persist created_co_num */' + @Lf
        + N'                co_num = @ExistingCoNum,' + @Lf
        + N'                created_co_num = @ExistingCoNum,' + @Lf
        + N'                process_status = N''P'',';

    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510275, N'[PATCH-26] Anchor existing-CO staging update tidak ditemukan tepat satu kali.', 1;

    SET @Definition = REPLACE(@Definition, @Old, @New);

    /* Newly-created Customer Order path. */
    SET @Old =
          N'        UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
        + N'        SET' + @Lf
        + N'            co_num = @CreatedCoNum,' + @Lf
        + N'            process_status = N''P'',';

    SET @New =
          N'        UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
        + N'        SET' + @Lf
        + N'            co_num = @CreatedCoNum,' + @Lf
        + N'            created_co_num = @CreatedCoNum,' + @Lf
        + N'            process_status = N''P'',';

    SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
    IF ISNULL(@Count, 0) <> 1
        THROW 510276, N'[PATCH-26] Anchor new-CO staging update tidak ditemukan tepat satu kali.', 1;

    SET @Definition = REPLACE(@Definition, @Old, @New);

    /* Normalize procedure header for dynamic ALTER execution. */
    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
    BEGIN
        SET @Definition = REPLACE
        (
            @Definition,
            N'CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp'
        );
        SET @Definition = REPLACE
        (
            @Definition,
            N'CREATE PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp'
        );
        SET @Definition = REPLACE
        (
            @Definition,
            N'CREATE   PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp'
        );
    END;

    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
        THROW 510277, N'[PATCH-26] Header ProcessCustomerOrder tidak dapat dinormalisasi.', 1;

    EXEC sys.sp_executesql @Definition;
END;

/* -----------------------------------------------------------------------------
   Backfill existing Processed staging rows safely.
   Only rows whose SiteRef + customer + business Cust PO resolve to exactly one
   Blanket CO are updated. Ambiguous matches are deliberately skipped.
   ----------------------------------------------------------------------------- */
;WITH SafeMatch AS
(
    SELECT
        t.RowPointer,
        MIN(c.co_num) AS created_co_num
    FROM dbo.ue_SMK069_temp_sales_mst AS t
    INNER JOIN dbo.co_mst AS c
        ON c.site_ref = t.SiteRef
       AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_num)))
           = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_num)))
       AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_po)))
           = LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po)))
       AND c.[type] = N'B'
    WHERE t.process_status = N'P'
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.created_co_num))), N'') IS NULL
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))), N'') IS NOT NULL
    GROUP BY t.RowPointer
    HAVING COUNT(DISTINCT c.co_num) = 1
)
UPDATE t
SET
    t.created_co_num = m.created_co_num,
    t.RecordDate = GETDATE(),
    t.UpdatedBy = CONVERT(NVARCHAR(128), SUSER_SNAME())
FROM dbo.ue_SMK069_temp_sales_mst AS t
INNER JOIN SafeMatch AS m
    ON m.RowPointer = t.RowPointer;

/* Post-check installed procedure. */
SET @Definition = OBJECT_DEFINITION(@ProcId);
IF CHARINDEX(N'PATCH-26: persist created_co_num', COALESCE(@Definition, N'')) = 0
    THROW 510278, N'[PATCH-26] Post-check marker created_co_num gagal.', 1;
IF CHARINDEX(N'created_co_num = @ExistingCoNum', COALESCE(@Definition, N'')) = 0
    THROW 510279, N'[PATCH-26] Existing-CO path belum mengisi created_co_num.', 1;
IF CHARINDEX(N'created_co_num = @CreatedCoNum', COALESCE(@Definition, N'')) = 0
    THROW 510280, N'[PATCH-26] New-CO path belum mengisi created_co_num.', 1;

PRINT N'[PATCH-26] SUCCESS - created_co_num dipersist untuk existing/new CO dan historical Processed rows di-backfill secara aman.';
