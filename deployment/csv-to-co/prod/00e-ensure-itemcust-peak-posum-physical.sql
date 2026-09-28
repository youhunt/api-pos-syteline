/* =============================================================================
   SMK069 PROD - ENSURE ITEMCUST PEAK/POS UOM PHYSICAL COLUMNS
   Scope : CSV / POS inbound -> Blanket Customer Order ONLY
   Date  : 2026-09-28
   Mode  : Apply Database compatible, ONE BATCH, NO GO

   DEV-proven fields:
   - itemcust_mst.Uf_SMK069_is_peak_season : INT NOT NULL DEFAULT 0
   - itemcust_mst.Uf_SMK069_pos_um         : UMType NULL

   IMPORTANT:
   This establishes the physical DB contract required by the mapping/view/runtime.
   Mongoose UET metadata/class/form metadata is handled separately.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.itemcust_mst', N'U') IS NULL
    THROW 521101, N'[SMK069 UET] dbo.itemcust_mst tidak ditemukan.', 1;

IF TYPE_ID(N'dbo.UMType') IS NULL
    THROW 521102, N'[SMK069 UET] dbo.UMType tidak ditemukan.', 1;

/* Peak Season flag */
IF COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_is_peak_season') IS NULL
BEGIN
    ALTER TABLE dbo.itemcust_mst
        ADD Uf_SMK069_is_peak_season INT NOT NULL
            CONSTRAINT DF_itemcust_Uf_SMK069_is_peak_season DEFAULT ((0));

    PRINT N'[SMK069 UET] CREATED itemcust_mst.Uf_SMK069_is_peak_season';
END
ELSE
    PRINT N'[SMK069 UET] EXISTS itemcust_mst.Uf_SMK069_is_peak_season';

/* POS U/M */
IF COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_pos_um') IS NULL
BEGIN
    ALTER TABLE dbo.itemcust_mst
        ADD Uf_SMK069_pos_um dbo.UMType NULL;

    PRINT N'[SMK069 UET] CREATED itemcust_mst.Uf_SMK069_pos_um';
END
ELSE
    PRINT N'[SMK069 UET] EXISTS itemcust_mst.Uf_SMK069_pos_um';

/* Physical contract verification */
IF COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_is_peak_season') IS NULL
    THROW 521103, N'[SMK069 UET] Peak Season column gagal dibuat.', 1;

IF COL_LENGTH(N'dbo.itemcust_mst', N'Uf_SMK069_pos_um') IS NULL
    THROW 521104, N'[SMK069 UET] POS U/M column gagal dibuat.', 1;

PRINT N'[SMK069 UET] SUCCESS - itemcust physical Peak/POS U/M contract ready.';
