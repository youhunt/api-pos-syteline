/* =============================================================================
   SMK069 - Patch 23 - Persist generated SyteLine CO number to staging
   -----------------------------------------------------------------------------
   Date    : 2026-09-16
   Objects : dbo.ue_SMK069_temp_sales_mst
             dbo.SMK069ProcessBatchCustomerOrdersSp
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY

   TENANT EVIDENCE
   ---------------
   Error Processing shows rows as Processed but the visible "SyteLine CO Number"
   remains blank for source orders such as R260904069 / DEV4-233 and
   R260904070 / DEV4-238.

   ROOT CAUSE
   ----------
   SMK069ProcessCustomerOrderSp returns @CreatedCoNum to the batch processor,
   but the staging table has no persisted target/generated CO number. The base
   staging design only stores source co_num plus process status/audit fields.

   FIX
   ---
   1. Add nullable dbo.ue_SMK069_temp_sales_mst.syteline_co_num NVARCHAR(10).
   2. After each successful order process, persist @CreatedCoNum against the
      technical source co_num in SMK069ProcessBatchCustomerOrdersSp.
   3. Safely backfill existing Processed rows only when exactly one Blanket CO
      matches SiteRef + mapped customer + business cust_po.

   SAFETY
   ------
   - Source/POS co_num is NOT overwritten.
   - Business cust_po is NOT overwritten.
   - Ambiguous historical matches are deliberately not backfilled.
   - No standard SyteLine table is altered.
   - One executable batch; NO GO (Apply Database compatible).

   MONGOOSE METADATA NOTE
   ----------------------
   After this SQL patch, refresh/resynchronize SQL Table / IDO metadata for
   SMK069_temp_sales_mst / ue_SMK069TempSales and bind the Error Processing
   "SyteLine CO Number" component to object.syteline_co_num.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    THROW 510230, N'[PATCH-23] dbo.ue_SMK069_temp_sales_mst tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'syteline_co_num') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_temp_sales_mst
        ADD syteline_co_num NVARCHAR(10) NULL;
END;

DECLARE
    @ProcName   SYSNAME       = N'dbo.SMK069ProcessBatchCustomerOrdersSp',
    @ProcId     INT,
    @Definition NVARCHAR(MAX),
    @Lf         NCHAR(1)      = NCHAR(10),
    @Old        NVARCHAR(MAX),
    @New        NVARCHAR(MAX),
    @Count      INT;

SET @ProcId = OBJECT_ID(@ProcName, N'P');
IF @ProcId IS NULL
    THROW 510231, N'[PATCH-23] dbo.SMK069ProcessBatchCustomerOrdersSp tidak ditemukan. Apply Patch 19/20 terlebih dahulu.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);
IF NULLIF(@Definition, N'') IS NULL
    THROW 510232, N'[PATCH-23] Definition SMK069ProcessBatchCustomerOrdersSp tidak dapat dibaca.', 1;

SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

IF CHARINDEX(N'PATCH-23: persist generated SyteLine CO number', @Definition) = 0
BEGIN
    SET @Old =
          N'        IF ISNULL(@Success, 0) = 1' + @Lf
        + N'        BEGIN' + @Lf
        + N'            SET @ProcessedOrders += 1;' + @Lf + @Lf
        + N'            IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))), N'''') IS NOT NULL';

    SET @New =
          N'        IF ISNULL(@Success, 0) = 1' + @Lf
        + N'        BEGIN' + @Lf
        + N'            SET @ProcessedOrders += 1;' + @Lf + @Lf
        + N'            /* PATCH-23: persist generated SyteLine CO number */' + @Lf
        + N'            IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))), N'''') IS NOT NULL' + @Lf
        + N'            BEGIN' + @Lf
        + N'                UPDATE dbo.ue_SMK069_temp_sales_mst' + @Lf
        + N'                SET' + @Lf
        + N'                    syteline_co_num = CONVERT(NVARCHAR(10), @CreatedCoNum),' + @Lf
        + N'                    RecordDate = GETDATE(),' + @Lf
        + N'                    UpdatedBy = @ProcessedBy' + @Lf
        + N'                WHERE SiteRef = @SiteRef' + @Lf
        + N'                  AND LTRIM(RTRIM(co_num)) = LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CoNum)));' + @Lf
        + N'            END;' + @Lf + @Lf
        + N'            IF NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(60), @CreatedCoNum))), N'''') IS NOT NULL';

    SET @Count =
        (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);

    IF ISNULL(@Count, 0) <> 1
        THROW 510233, N'[PATCH-23] Anchor success SMK069ProcessBatchCustomerOrdersSp tidak ditemukan tepat satu kali.', 1;

    SET @Definition = REPLACE(@Definition, @Old, @New);

    /* Normalize module header for execution. */
    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp', @Definition) = 0
    BEGIN
        SET @Definition = REPLACE
        (
            @Definition,
            N'CREATE OR ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp'
        );
        SET @Definition = REPLACE
        (
            @Definition,
            N'CREATE PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp'
        );
        SET @Definition = REPLACE
        (
            @Definition,
            N'CREATE   PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp',
            N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp'
        );
    END;

    IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessBatchCustomerOrdersSp', @Definition) = 0
        THROW 510234, N'[PATCH-23] Header SMK069ProcessBatchCustomerOrdersSp tidak dapat dinormalisasi menjadi ALTER PROCEDURE.', 1;

    EXEC sys.sp_executesql @Definition;
END;

/*
   Safe historical backfill.
   Dynamic SQL is intentional because the column may have been added above in
   this same Apply Database batch.
*/
DECLARE @BackfillSql NVARCHAR(MAX) = N'
;WITH SourceOrders AS
(
    SELECT DISTINCT
        t.SiteRef,
        LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))) AS SourceCoNum,
        LTRIM(RTRIM(CONVERT(NVARCHAR(40), t.cust_num))) AS CustNum,
        LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))) AS CustPo
    FROM dbo.ue_SMK069_temp_sales_mst AS t
    WHERE t.process_status = N''P''
      AND t.syteline_co_num IS NULL
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))), N'''') IS NOT NULL
),
Candidates AS
(
    SELECT
        s.SiteRef,
        s.SourceCoNum,
        c.co_num AS TargetCoNum
    FROM SourceOrders AS s
    INNER JOIN dbo.co_mst AS c
        ON c.site_ref = s.SiteRef
       AND LTRIM(RTRIM(CONVERT(NVARCHAR(40), c.cust_num))) = s.CustNum
       AND LTRIM(RTRIM(CONVERT(NVARCHAR(100), c.cust_po))) = s.CustPo
       AND c.[type] = N''B''
),
UniqueMap AS
(
    SELECT
        SiteRef,
        SourceCoNum,
        MIN(TargetCoNum) AS TargetCoNum
    FROM Candidates
    GROUP BY SiteRef, SourceCoNum
    HAVING COUNT(DISTINCT TargetCoNum) = 1
)
UPDATE t
SET
    t.syteline_co_num = CONVERT(NVARCHAR(10), u.TargetCoNum),
    t.RecordDate = GETDATE(),
    t.UpdatedBy = SUSER_SNAME()
FROM dbo.ue_SMK069_temp_sales_mst AS t
INNER JOIN UniqueMap AS u
    ON u.SiteRef = t.SiteRef
   AND u.SourceCoNum = LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num)))
WHERE t.process_status = N''P''
  AND t.syteline_co_num IS NULL;
';

EXEC sys.sp_executesql @BackfillSql;

/* Post-check. */
SET @Definition = OBJECT_DEFINITION(@ProcId);
IF CHARINDEX(N'PATCH-23: persist generated SyteLine CO number', COALESCE(@Definition, N'')) = 0
    THROW 510235, N'[PATCH-23] Post-check persistence syteline_co_num gagal.', 1;

PRINT N'[PATCH-23] SUCCESS - generated SyteLine CO number sekarang dipersist ke staging; unique historical Processed rows sudah dibackfill.';