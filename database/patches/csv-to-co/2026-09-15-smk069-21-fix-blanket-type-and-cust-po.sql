/* =============================================================================
   SMK069 - Patch 21 - Fix Auto CO Blanket type and Cust PO mapping
   -----------------------------------------------------------------------------
   Date    : 2026-09-15
   Object  : dbo.SMK069ProcessCustomerOrderSp
   Scope   : CSV / POS inbound -> Customer Order ONLY

   TENANT EVIDENCE
   ---------------
   UAT source order R260904065 / business CustPo DEV4-231 created CO26090002 as:
       co_mst.cust_po = R260904065   -- WRONG: source/POS order number
       co_mst.type    = R            -- WRONG: Regular
       co_mst.consolidate = 1        -- already correct

   ROOT CAUSE
   ----------
   The processor used @SourceCoNum for co_mst.cust_po and did not explicitly
   write co_mst.type. SyteLine therefore applied its Regular-order default.

   REQUIRED RESULT FOR NEW COs
   ---------------------------
       co_mst.cust_po      = staging cust_po (example DEV4-231)
       co_mst.type         = B
       co_mst.consolidate  = 1
       coitem_mst.stat     = O
       coitem_mst.consolidate = 1

   IMPORTANT
   ---------
   - @SourceCoNum remains the technical staging/source order key.
   - Business cust_po is read from ue_SMK069_temp_sales_mst.
   - Idempotency lookup is changed to business Cust PO, not SourceCoNum.
   - Existing COs are NOT mass-updated by this patch.
   - One executable batch; NO GO (Apply Database compatible).
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @ProcName SYSNAME = N'dbo.SMK069ProcessCustomerOrderSp',
    @ProcId INT,
    @Definition NVARCHAR(MAX),
    @Lf NCHAR(1) = NCHAR(10),
    @Old NVARCHAR(MAX),
    @New NVARCHAR(MAX),
    @Count INT;

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'cust_po') IS NULL
    THROW 510210, N'[PATCH-21] Kolom staging cust_po tidak ditemukan.', 1;
IF COL_LENGTH(N'dbo.co_mst', N'cust_po') IS NULL
    THROW 510211, N'[PATCH-21] Kolom co_mst.cust_po tidak ditemukan.', 1;
IF COL_LENGTH(N'dbo.co_mst', N'type') IS NULL
    THROW 510212, N'[PATCH-21] Kolom co_mst.type tidak ditemukan.', 1;
IF COL_LENGTH(N'dbo.co_mst', N'consolidate') IS NULL
    THROW 510213, N'[PATCH-21] Kolom co_mst.consolidate tidak ditemukan.', 1;
IF COL_LENGTH(N'dbo.coitem_mst', N'consolidate') IS NULL
    THROW 510214, N'[PATCH-21] Kolom coitem_mst.consolidate tidak ditemukan.', 1;

SET @ProcId = OBJECT_ID(@ProcName, N'P');
IF @ProcId IS NULL
    THROW 510215, N'[PATCH-21] SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);
IF NULLIF(@Definition, N'') IS NULL
    THROW 510216, N'[PATCH-21] Definition procedure tidak dapat dibaca.', 1;

SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

/* Idempotent exit when the complete Patch-21 mapping is already present. */
IF CHARINDEX(N'@CustPo                  NVARCHAR(100)', @Definition) > 0
   AND CHARINDEX(N'AND LTRIM(RTRIM(cust_po)) = @CustPo', @Definition) > 0
   AND CHARINDEX(N'            cust_po,' + @Lf + N'            [type],', @Definition) > 0
   AND CHARINDEX(N'            @CustPo,' + @Lf + N'            N''B'',', @Definition) > 0
BEGIN
    PRINT N'[PATCH-21] Blanket type B + business Cust PO mapping sudah terpasang.';
    RETURN;
END;

/* -------------------------------------------------------------------------
   1. Declare @CustPo.
   ------------------------------------------------------------------------- */
SET @Old =
      N'        @CustNum                 CustNumType,' + @Lf
    + N'        @OrderDate               DateType,';
SET @New =
      N'        @CustNum                 CustNumType,' + @Lf
    + N'        @CustPo                  NVARCHAR(100),' + @Lf
    + N'        @OrderDate               DateType,';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510217, N'[PATCH-21] Anchor deklarasi @CustPo tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* -------------------------------------------------------------------------
   2. Read business cust_po from staging together with the order header data.
   ------------------------------------------------------------------------- */
SET @Old =
      N'            @LineCount      = COUNT(*),' + @Lf
    + N'            @CustNum        = MIN(LTRIM(RTRIM(cust_num))),' + @Lf
    + N'            @OrderDate      = MIN(order_date),';
SET @New =
      N'            @LineCount      = COUNT(*),' + @Lf
    + N'            @CustNum        = MIN(LTRIM(RTRIM(cust_num))),' + @Lf
    + N'            @CustPo         = MIN(NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))), N'''')),' + @Lf
    + N'            @OrderDate      = MIN(order_date),';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510218, N'[PATCH-21] Anchor pembacaan staging header tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* -------------------------------------------------------------------------
   3. Cust PO is mandatory and must be identical on every line of a source PO.
   ------------------------------------------------------------------------- */
SET @Old =
      N'        IF ISNULL(@LineCount, 0) = 0' + @Lf
    + N'            THROW 50005, N''Order staging tidak memiliki line.'', 1;';
SET @New =
      @Old + @Lf + @Lf
    + N'        IF NULLIF(LTRIM(RTRIM(@CustPo)), N'''') IS NULL' + @Lf
    + N'            THROW 50029, N''cust_po wajib diisi untuk Customer Order.'', 1;' + @Lf + @Lf
    + N'        IF EXISTS' + @Lf
    + N'        (' + @Lf
    + N'            SELECT 1' + @Lf
    + N'            FROM dbo.ue_SMK069_temp_sales_mst' + @Lf
    + N'            WHERE SiteRef = @SiteRef' + @Lf
    + N'              AND LTRIM(RTRIM(co_num)) = @SourceCoNum' + @Lf
    + N'              AND' + @Lf
    + N'              (' + @Lf
    + N'                  NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))), N'''') IS NULL' + @Lf
    + N'                  OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), cust_po))) <> @CustPo' + @Lf
    + N'              )' + @Lf
    + N'        )' + @Lf
    + N'            THROW 50030, N''Satu source co_num hanya boleh memiliki satu cust_po.'', 1;';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510219, N'[PATCH-21] Anchor validasi line count tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* -------------------------------------------------------------------------
   4. Idempotency is business PO based.
   ------------------------------------------------------------------------- */
SET @Old = N'          AND LTRIM(RTRIM(cust_po)) = @SourceCoNum';
SET @New = N'          AND LTRIM(RTRIM(cust_po)) = @CustPo';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510220, N'[PATCH-21] Anchor idempotency cust_po tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* Existing order with same Cust PO must itself already be Blanket. */
SET @Old =
      N'        IF @ExistingCoNum IS NOT NULL' + @Lf
    + N'        BEGIN' + @Lf
    + N'            SELECT';
SET @New =
      N'        IF @ExistingCoNum IS NOT NULL' + @Lf
    + N'        BEGIN' + @Lf
    + N'            IF EXISTS' + @Lf
    + N'            (' + @Lf
    + N'                SELECT 1' + @Lf
    + N'                FROM dbo.co_mst' + @Lf
    + N'                WHERE site_ref = @SiteRef' + @Lf
    + N'                  AND co_num = @ExistingCoNum' + @Lf
    + N'                  AND ISNULL([type], N'''') <> N''B''' + @Lf
    + N'            )' + @Lf
    + N'                THROW 50031, N''Cust PO sudah memiliki Customer Order tetapi bukan Blanket type B.'', 1;' + @Lf + @Lf
    + N'            SELECT';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510221, N'[PATCH-21] Anchor existing-order check tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* -------------------------------------------------------------------------
   5. Header mapping: business Cust PO + explicit Blanket type B.
   ------------------------------------------------------------------------- */
SET @Old =
      N'            cust_num,' + @Lf
    + N'            cust_po,' + @Lf
    + N'            cust_seq,';
SET @New =
      N'            cust_num,' + @Lf
    + N'            cust_po,' + @Lf
    + N'            [type],' + @Lf
    + N'            cust_seq,';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510222, N'[PATCH-21] Anchor column-list co_mst tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

SET @Old =
      N'            @CreatedCoNum,' + @Lf
    + N'            @CustNum,' + @Lf
    + N'            @SourceCoNum,' + @Lf
    + N'            @CustSeq,';
SET @New =
      N'            @CreatedCoNum,' + @Lf
    + N'            @CustNum,' + @Lf
    + N'            @CustPo,' + @Lf
    + N'            N''B'',' + @Lf
    + N'            @CustSeq,';
SET @Count = (LEN(@Definition) - LEN(REPLACE(@Definition, @Old, N''))) / NULLIF(LEN(@Old), 0);
IF ISNULL(@Count, 0) <> 1
    THROW 510223, N'[PATCH-21] Anchor VALUES co_mst tidak ditemukan tepat satu kali.', 1;
SET @Definition = REPLACE(@Definition, @Old, @New);

/* Patch 17 must still be present. Refuse to regress consolidate behavior. */
IF CHARINDEX(N'            include_tax_in_price,' + @Lf
             + N'            consolidate,' + @Lf
             + N'            [cost]', @Definition) = 0
    THROW 510224, N'[PATCH-21] co_mst.consolidate mapping tidak ditemukan. Apply Patch 17 Rev.6 dulu.', 1;

IF CHARINDEX(N'            stat,' + @Lf
             + N'            consolidate' + @Lf, @Definition) = 0
    THROW 510225, N'[PATCH-21] coitem_mst.consolidate mapping tidak ditemukan. Apply Patch 17 Rev.6 dulu.', 1;

/* Normalize known module headers to ALTER PROCEDURE for executable definition. */
IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
BEGIN
    SET @Definition = REPLACE(@Definition,
        N'CREATE   PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
        N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
    SET @Definition = REPLACE(@Definition,
        N'CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
        N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
    SET @Definition = REPLACE(@Definition,
        N'CREATE PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
        N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp');
END;

IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
    THROW 510226, N'[PATCH-21] Header procedure tidak dapat dinormalisasi menjadi ALTER PROCEDURE.', 1;

EXEC sys.sp_executesql @Definition;

/* Post checks. */
SET @Definition = OBJECT_DEFINITION(@ProcId);
SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

IF CHARINDEX(N'AND LTRIM(RTRIM(cust_po)) = @CustPo', @Definition) = 0
    THROW 510227, N'[PATCH-21] Post-check idempotency Cust PO gagal.', 1;
IF CHARINDEX(N'            cust_po,' + @Lf + N'            [type],', @Definition) = 0
    THROW 510228, N'[PATCH-21] Post-check co_mst.type gagal.', 1;
IF CHARINDEX(N'            @CustPo,' + @Lf + N'            N''B'',', @Definition) = 0
    THROW 510229, N'[PATCH-21] Post-check business Cust PO / Blanket value gagal.', 1;

PRINT N'[PATCH-21] SUCCESS - Auto CO baru memakai cust_po staging dan co_mst.type = B.';
