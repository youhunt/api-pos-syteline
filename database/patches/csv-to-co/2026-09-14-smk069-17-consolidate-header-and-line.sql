/* =============================================================================
   SMK069 - CSV/POS Inbound -> Blanket Customer Order
   Patch 17 Rev.4 - Force consolidate = 1 on co_mst and coitem_mst
   Date     : 2026-09-14

   Tenant-confirmed fields
   -----------------------
       dbo.co_mst.consolidate     tinyint
       dbo.coitem_mst.consolidate tinyint

   Requirement
   -----------
   New Customer Orders created by SMK069ProcessCustomerOrderSp must explicitly
   set:
       dbo.co_mst.consolidate     = 1
       dbo.coitem_mst.consolidate = 1

   REV.4
   -----
   - Keeps Rev.2 BIT-to-INT fix for the partial-state guard.
   - Keeps Rev.3 tenant-confirmed field name: consolidate.
   - Fixes Apply Database header normalization so it no longer depends on the
     exact schema/object text format. It accepts CREATE/ALTER, PROC/PROCEDURE,
     and bracketed object names such as [dbo].[SMK069ProcessCustomerOrderSp].
   - Verifies BOTH tenant columns exist before altering the procedure.
   - Refuses partial/ambiguous source matches.
   - Idempotent when both mappings are already installed.
   - One executable batch; no GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @ProcName          SYSNAME = N'dbo.SMK069ProcessCustomerOrderSp',
    @ProcId            INT,
    @Definition        NVARCHAR(MAX),
    @DefinitionUpper   NVARCHAR(MAX),
    @Lf                NCHAR(1) = NCHAR(10),
    @HdrColOld         NVARCHAR(MAX),
    @HdrColNew         NVARCHAR(MAX),
    @HdrValOld         NVARCHAR(MAX),
    @HdrValNew         NVARCHAR(MAX),
    @LineColOld        NVARCHAR(MAX),
    @LineColNew        NVARCHAR(MAX),
    @LineValOld        NVARCHAR(MAX),
    @LineValNew        NVARCHAR(MAX),
    @HdrColCount       INT,
    @HdrValCount       INT,
    @LineColCount      INT,
    @LineValCount      INT,
    @HasHdrColumn      BIT,
    @HasHdrValue       BIT,
    @HasLineColumn     BIT,
    @HasLineValue      BIT,
    @HeaderPos         INT,
    @HeaderLen         INT;

IF COL_LENGTH(N'dbo.co_mst', N'consolidate') IS NULL
    THROW 510170, N'[PATCH-17] Kolom dbo.co_mst.consolidate tidak ditemukan. Patch dihentikan.', 1;

IF COL_LENGTH(N'dbo.coitem_mst', N'consolidate') IS NULL
    THROW 510171, N'[PATCH-17] Kolom dbo.coitem_mst.consolidate tidak ditemukan. Patch dihentikan.', 1;

SET @ProcId = OBJECT_ID(@ProcName, N'P');
IF @ProcId IS NULL
    THROW 510172, N'[PATCH-17] dbo.SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);
IF NULLIF(@Definition, N'') IS NULL
    THROW 510173, N'[PATCH-17] Definition SMK069ProcessCustomerOrderSp tidak dapat dibaca.', 1;

/* Normalize CR/LF so exact INSERT-list replacements are deterministic. */
SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

SET @HasHdrColumn = CASE WHEN CHARINDEX(
      N'            include_tax_in_price,' + @Lf
    + N'            consolidate,' + @Lf
    + N'            [cost]', @Definition) > 0 THEN 1 ELSE 0 END;

SET @HasHdrValue = CASE WHEN CHARINDEX(
      N'            @IncludeTaxInPrice,' + @Lf
    + N'            1,' + @Lf
    + N'            @HeaderCost', @Definition) > 0 THEN 1 ELSE 0 END;

SET @HasLineColumn = CASE WHEN CHARINDEX(
      N'            matl_cost_conv,' + @Lf
    + N'            stat,' + @Lf
    + N'            consolidate' + @Lf
    + N'        )', @Definition) > 0 THEN 1 ELSE 0 END;

SET @HasLineValue = CASE WHEN CHARINDEX(
      N'            ISNULL(i.matl_cost, 0),' + @Lf
    + N'            N''O'',' + @Lf
    + N'            1' + @Lf
    + N'        FROM dbo.ue_SMK069_temp_sales_mst AS s', @Definition) > 0 THEN 1 ELSE 0 END;

IF @HasHdrColumn = 1 AND @HasHdrValue = 1 AND @HasLineColumn = 1 AND @HasLineValue = 1
BEGIN
    PRINT N'[PATCH-17] consolidate = 1 sudah terpasang pada co_mst dan coitem_mst. Tidak ada perubahan.';
    RETURN;
END;

/* A partially-patched definition is unsafe to mutate automatically. */
IF CONVERT(INT, @HasHdrColumn)
 + CONVERT(INT, @HasHdrValue)
 + CONVERT(INT, @HasLineColumn)
 + CONVERT(INT, @HasLineValue) > 0
    THROW 510174, N'[PATCH-17] Ditemukan state consolidate yang hanya terpasang sebagian. Patch dihentikan untuk inspeksi manual.', 1;

/* Header: add co_mst.consolidate after include_tax_in_price. */
SET @HdrColOld =
      N'            include_tax_in_price,' + @Lf
    + N'            [cost],' + @Lf
    + N'            matl_cost_t,' + @Lf
    + N'            price' + @Lf
    + N'        )';

SET @HdrColNew =
      N'            include_tax_in_price,' + @Lf
    + N'            consolidate,' + @Lf
    + N'            [cost],' + @Lf
    + N'            matl_cost_t,' + @Lf
    + N'            price' + @Lf
    + N'        )';

SET @HdrValOld =
      N'            @IncludeTaxInPrice,' + @Lf
    + N'            @HeaderCost,' + @Lf
    + N'            @HeaderMatlCost,' + @Lf
    + N'            @HeaderPrice' + @Lf
    + N'        );';

SET @HdrValNew =
      N'            @IncludeTaxInPrice,' + @Lf
    + N'            1,' + @Lf
    + N'            @HeaderCost,' + @Lf
    + N'            @HeaderMatlCost,' + @Lf
    + N'            @HeaderPrice' + @Lf
    + N'        );';

/* Line: add coitem_mst.consolidate after stat. */
SET @LineColOld =
      N'            matl_cost,' + @Lf
    + N'            cost_conv,' + @Lf
    + N'            matl_cost_conv,' + @Lf
    + N'            stat' + @Lf
    + N'        )' + @Lf
    + N'        SELECT';

SET @LineColNew =
      N'            matl_cost,' + @Lf
    + N'            cost_conv,' + @Lf
    + N'            matl_cost_conv,' + @Lf
    + N'            stat,' + @Lf
    + N'            consolidate' + @Lf
    + N'        )' + @Lf
    + N'        SELECT';

SET @LineValOld =
      N'            ISNULL(i.matl_cost, 0),' + @Lf
    + N'            ISNULL(i.unit_cost, 0),' + @Lf
    + N'            ISNULL(i.matl_cost, 0),' + @Lf
    + N'            N''O''' + @Lf
    + N'        FROM dbo.ue_SMK069_temp_sales_mst AS s';

SET @LineValNew =
      N'            ISNULL(i.matl_cost, 0),' + @Lf
    + N'            ISNULL(i.unit_cost, 0),' + @Lf
    + N'            ISNULL(i.matl_cost, 0),' + @Lf
    + N'            N''O'',' + @Lf
    + N'            1' + @Lf
    + N'        FROM dbo.ue_SMK069_temp_sales_mst AS s';

SET @HdrColCount =
    (LEN(@Definition) - LEN(REPLACE(@Definition, @HdrColOld, N''))) / NULLIF(LEN(@HdrColOld), 0);
SET @HdrValCount =
    (LEN(@Definition) - LEN(REPLACE(@Definition, @HdrValOld, N''))) / NULLIF(LEN(@HdrValOld), 0);
SET @LineColCount =
    (LEN(@Definition) - LEN(REPLACE(@Definition, @LineColOld, N''))) / NULLIF(LEN(@LineColOld), 0);
SET @LineValCount =
    (LEN(@Definition) - LEN(REPLACE(@Definition, @LineValOld, N''))) / NULLIF(LEN(@LineValOld), 0);

IF ISNULL(@HdrColCount, 0) <> 1
    THROW 510175, N'[PATCH-17] Target column-list co_mst tidak ditemukan tepat satu kali.', 1;
IF ISNULL(@HdrValCount, 0) <> 1
    THROW 510176, N'[PATCH-17] Target VALUES co_mst tidak ditemukan tepat satu kali.', 1;
IF ISNULL(@LineColCount, 0) <> 1
    THROW 510177, N'[PATCH-17] Target column-list coitem_mst tidak ditemukan tepat satu kali.', 1;
IF ISNULL(@LineValCount, 0) <> 1
    THROW 510178, N'[PATCH-17] Target SELECT coitem_mst tidak ditemukan tepat satu kali.', 1;

SET @Definition = REPLACE(@Definition, @HdrColOld, @HdrColNew);
SET @Definition = REPLACE(@Definition, @HdrValOld, @HdrValNew);
SET @Definition = REPLACE(@Definition, @LineColOld, @LineColNew);
SET @Definition = REPLACE(@Definition, @LineValOld, @LineValNew);

/*
   Rev.4: normalize only the CREATE/ALTER keyword portion of the installed
   module header. Do not depend on whether the object name is bracketed.
*/
SET @DefinitionUpper = UPPER(@Definition);
SET @HeaderPos = 0;
SET @HeaderLen = 0;

IF CHARINDEX(N'CREATE OR ALTER PROCEDURE', @DefinitionUpper) > 0
BEGIN
    SET @HeaderPos = CHARINDEX(N'CREATE OR ALTER PROCEDURE', @DefinitionUpper);
    SET @HeaderLen = LEN(N'CREATE OR ALTER PROCEDURE');
END
ELSE IF CHARINDEX(N'CREATE OR ALTER PROC', @DefinitionUpper) > 0
BEGIN
    SET @HeaderPos = CHARINDEX(N'CREATE OR ALTER PROC', @DefinitionUpper);
    SET @HeaderLen = LEN(N'CREATE OR ALTER PROC');
END
ELSE IF CHARINDEX(N'CREATE PROCEDURE', @DefinitionUpper) > 0
BEGIN
    SET @HeaderPos = CHARINDEX(N'CREATE PROCEDURE', @DefinitionUpper);
    SET @HeaderLen = LEN(N'CREATE PROCEDURE');
END
ELSE IF CHARINDEX(N'CREATE PROC', @DefinitionUpper) > 0
BEGIN
    SET @HeaderPos = CHARINDEX(N'CREATE PROC', @DefinitionUpper);
    SET @HeaderLen = LEN(N'CREATE PROC');
END
ELSE IF CHARINDEX(N'ALTER PROCEDURE', @DefinitionUpper) > 0
BEGIN
    SET @HeaderPos = CHARINDEX(N'ALTER PROCEDURE', @DefinitionUpper);
    SET @HeaderLen = LEN(N'ALTER PROCEDURE');
END
ELSE IF CHARINDEX(N'ALTER PROC', @DefinitionUpper) > 0
BEGIN
    SET @HeaderPos = CHARINDEX(N'ALTER PROC', @DefinitionUpper);
    SET @HeaderLen = LEN(N'ALTER PROC');
END;

IF ISNULL(@HeaderPos, 0) = 0 OR ISNULL(@HeaderLen, 0) = 0
    THROW 510179, N'[PATCH-17] Keyword header CREATE/ALTER PROC/PROCEDURE tidak ditemukan pada module definition.', 1;

SET @Definition = STUFF(@Definition, @HeaderPos, @HeaderLen, N'ALTER PROCEDURE');
SET @DefinitionUpper = UPPER(@Definition);

IF CHARINDEX(N'ALTER PROCEDURE', @DefinitionUpper) = 0
   OR CHARINDEX(N'SMK069PROCESSCUSTOMERORDERSP', @DefinitionUpper) = 0
    THROW 510182, N'[PATCH-17] Header procedure gagal dinormalisasi secara aman.', 1;

EXEC sys.sp_executesql @Definition;

/* Post-check installed module. */
SET @Definition = OBJECT_DEFINITION(@ProcId);
SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

IF CHARINDEX(N'            include_tax_in_price,' + @Lf
             + N'            consolidate,' + @Lf
             + N'            [cost]', @Definition) = 0
    THROW 510180, N'[PATCH-17] Post-check co_mst.consolidate gagal.', 1;

IF CHARINDEX(N'            matl_cost_conv,' + @Lf
             + N'            stat,' + @Lf
             + N'            consolidate', @Definition) = 0
    THROW 510181, N'[PATCH-17] Post-check coitem_mst.consolidate gagal.', 1;

PRINT N'[PATCH-17] SUCCESS - co_mst.consolidate = 1 dan coitem_mst.consolidate = 1 untuk CO baru.';
