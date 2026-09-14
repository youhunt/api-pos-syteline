/* =============================================================================
   SMK069 - CSV/POS Inbound -> Blanket Customer Order
   Patch 14 - Force coitem_mst.stat = 'O' for newly-created CO lines
   Date     : 2026-09-14

   Reason
   ------
   SMK069ProcessCustomerOrderSp currently omits coitem_mst.stat from the
   INSERT column list. On the tenant this leaves the generated Customer Order
   line at the SyteLine default (shown as Planned on the form).

   Required result
   ---------------
   Every new coitem_mst row created by CSV/POS -> CO is inserted explicitly as:
       stat = 'O'

   Tenant deployment rules
   -----------------------
   - One executable batch.
   - No GO.
   - Verification SELECT is intentionally separate.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @ProcName      SYSNAME = N'dbo.SMK069ProcessCustomerOrderSp',
    @ProcId        INT,
    @Definition    NVARCHAR(MAX),
    @Lf            NCHAR(1) = NCHAR(10),
    @ColumnOld     NVARCHAR(MAX),
    @ColumnNew     NVARCHAR(MAX),
    @ValueOld      NVARCHAR(MAX),
    @ValueNew      NVARCHAR(MAX),
    @ColumnCount   INT,
    @ValueCount    INT;

SET @ProcId = OBJECT_ID(@ProcName, N'P');

IF @ProcId IS NULL
    THROW 510140, N'[PATCH-14] dbo.SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

SET @Definition = OBJECT_DEFINITION(@ProcId);

IF NULLIF(@Definition, N'') IS NULL
    THROW 510141, N'[PATCH-14] Definition SMK069ProcessCustomerOrderSp tidak dapat dibaca.', 1;

/* Normalize line endings so the targeted replacement is deterministic. */
SET @Definition = REPLACE(@Definition, NCHAR(13) + NCHAR(10), NCHAR(10));
SET @Definition = REPLACE(@Definition, NCHAR(13), NCHAR(10));

/* Idempotency: if the exact new column/value mapping is already present, stop safely. */
IF CHARINDEX(N'matl_cost_conv,' + @Lf + N'            stat', @Definition) > 0
   AND CHARINDEX(N'ISNULL(i.matl_cost, 0),' + @Lf + N'            N''O''' + @Lf
                 + N'        FROM dbo.ue_SMK069_temp_sales_mst AS s', @Definition) > 0
BEGIN
    PRINT N'[PATCH-14] coitem_mst.stat = O sudah terpasang. Tidak ada perubahan.';
    RETURN;
END;

SET @ColumnOld =
      N'            matl_cost_conv' + @Lf
    + N'        )' + @Lf
    + N'        SELECT';

SET @ColumnNew =
      N'            matl_cost_conv,' + @Lf
    + N'            stat' + @Lf
    + N'        )' + @Lf
    + N'        SELECT';

SET @ValueOld =
      N'            ISNULL(i.unit_cost, 0),' + @Lf
    + N'            ISNULL(i.matl_cost, 0)' + @Lf
    + N'        FROM dbo.ue_SMK069_temp_sales_mst AS s';

SET @ValueNew =
      N'            ISNULL(i.unit_cost, 0),' + @Lf
    + N'            ISNULL(i.matl_cost, 0),' + @Lf
    + N'            N''O''' + @Lf
    + N'        FROM dbo.ue_SMK069_temp_sales_mst AS s';

SET @ColumnCount =
    (LEN(@Definition) - LEN(REPLACE(@Definition, @ColumnOld, N''))) / NULLIF(LEN(@ColumnOld), 0);
SET @ValueCount =
    (LEN(@Definition) - LEN(REPLACE(@Definition, @ValueOld, N''))) / NULLIF(LEN(@ValueOld), 0);

IF ISNULL(@ColumnCount, 0) <> 1
    THROW 510142, N'[PATCH-14] Target column-list coitem_mst tidak ditemukan tepat satu kali. Patch dihentikan.', 1;

IF ISNULL(@ValueCount, 0) <> 1
    THROW 510143, N'[PATCH-14] Target SELECT-value coitem_mst tidak ditemukan tepat satu kali. Patch dihentikan.', 1;

SET @Definition = REPLACE(@Definition, @ColumnOld, @ColumnNew);
SET @Definition = REPLACE(@Definition, @ValueOld, @ValueNew);

/* OBJECT_DEFINITION can preserve CREATE/CREATE OR ALTER. Existing object must be ALTERed. */
SET @Definition = REPLACE
(
    @Definition,
    N'CREATE OR ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp',
    N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp'
);
SET @Definition = REPLACE
(
    @Definition,
    N'CREATE OR ALTER PROC dbo.SMK069ProcessCustomerOrderSp',
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
    N'CREATE PROC dbo.SMK069ProcessCustomerOrderSp',
    N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp'
);

IF CHARINDEX(N'ALTER PROCEDURE dbo.SMK069ProcessCustomerOrderSp', @Definition) = 0
    THROW 510144, N'[PATCH-14] Header procedure tidak dapat dinormalisasi menjadi ALTER PROCEDURE.', 1;

EXEC sys.sp_executesql @Definition;

PRINT N'[PATCH-14] SUCCESS - SMK069ProcessCustomerOrderSp sekarang mengisi coitem_mst.stat = O.';
