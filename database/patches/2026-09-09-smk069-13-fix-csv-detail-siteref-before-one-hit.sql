/* =============================================================================
   SMK069 - Patch 13 Rev.2 - Fix CSV detail SiteRef before CSV -> CO one-hit
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Object  : dbo.SMK069RunCsvTestBatchSp
   Purpose : Fix POS-402 when CSV parser shows detail rows on the form but the
             one-hit CSV -> Customer Order procedure cannot see them because
             ue_SMK069_pos_csv_upload_mst.SiteRef is NULL/blank or not aligned
             with the active Mongoose site.

   REV.2
   -----
   - Fixes Infor Apply Database error:
         Incorrect syntax near the keyword 'ELSE'
   - The previous revision had an effectively empty BEGIN/END branch containing
     only a comment. Some tenant SQL execution paths reject that shape at the
     following ELSE.
   - Prefix detection now uses LEN() instead of hard-coded lengths and gives
     every BEGIN/END branch an executable statement.

   TENANT / CODE EVIDENCE
   ----------------------
   - SMK069ImportCsvFileSp persists parsed rows to
     ue_SMK069_pos_csv_upload_mst but its INSERT does not explicitly populate
     the standard Mongoose SiteRef column.
   - SMK069RunCsvTestBatchSp is site-aware and requires:
         SiteRef = @Site AND batch_id = @BatchId
     before it considers detail rows present.
   - Therefore rows can be visible in the form by batch_id while the one-hit
     processor returns:
         [POS-402] Batch CSV belum memiliki detail transaksi.

   IMPORTANT: SiteRef vs siteref
   -----------------------------
   SiteRef = standard Mongoose site ownership column used by site-aware SQL.
   siteref = business/source field parsed from the CSV and may legitimately be
             blank when the CSV does not provide site/site_ref/siteref.

   Patch 13 fixes SiteRef because that is the field used by the one-hit
   preflight. It does not require the CSV business field siteref to be populated.

   Designed for Infor Apply Database: one executable batch, no GO separator.
   ============================================================================= */

SET NOCOUNT ON;

DECLARE
    @ObjectId          INT,
    @Definition        NVARCHAR(MAX),
    @Needle            NVARCHAR(400),
    @InsertPos         INT,
    @PatchMarker       NVARCHAR(200),
    @Snippet           NVARCHAR(MAX),
    @NewDef            NVARCHAR(MAX),
    @TrimmedNewDef     NVARCHAR(MAX),
    @CreatePrefix      NVARCHAR(50),
    @CreateAlterPrefix NVARCHAR(50),
    @AlterPrefix       NVARCHAR(50);

SET @ObjectId = OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp', N'P');

IF @ObjectId IS NULL
BEGIN
    RAISERROR('dbo.SMK069RunCsvTestBatchSp tidak ditemukan.', 16, 1);
    RETURN;
END;

SET @Definition = OBJECT_DEFINITION(@ObjectId);

IF @Definition IS NULL
BEGIN
    RAISERROR('Definition dbo.SMK069RunCsvTestBatchSp tidak dapat dibaca.', 16, 1);
    RETURN;
END;

SET @PatchMarker = N'/* SMK069 PATCH13 CSV DETAIL SITEREF NORMALIZATION */';

IF CHARINDEX(@PatchMarker, @Definition) > 0
BEGIN
    PRINT 'Patch 13 sudah terpasang pada dbo.SMK069RunCsvTestBatchSp.';
    RETURN;
END;

SET @Needle = N'EXEC SetSiteSp @Site, NULL;';
SET @InsertPos = CHARINDEX(@Needle, @Definition);

IF @InsertPos = 0
BEGIN
    RAISERROR('Marker SetSiteSp tidak ditemukan pada SMK069RunCsvTestBatchSp. Patch dihentikan untuk keamanan.', 16, 1);
    RETURN;
END;

SET @InsertPos = @InsertPos + LEN(@Needle);

SET @Snippet = N'

    /* SMK069 PATCH13 CSV DETAIL SITEREF NORMALIZATION */
    /* Normalize STANDARD Mongoose SiteRef for parsed detail rows. */
    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_pos_csv_batch_mst AS b
        WHERE b.SiteRef = @Site
          AND b.batch_id = @BatchId
    )
    BEGIN
        UPDATE d
        SET d.SiteRef    = @Site,
            d.UpdatedBy  = COALESCE(NULLIF(LTRIM(RTRIM(@RequestedBy)), N''''), SUSER_SNAME()),
            d.RecordDate = GETDATE()
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        WHERE d.batch_id = @BatchId
          AND ISNULL(LTRIM(RTRIM(CONVERT(NVARCHAR(8), d.SiteRef))), N'''') <> @Site;
    END;
';

SET @NewDef = STUFF(@Definition, @InsertPos + 1, 0, @Snippet);
SET @TrimmedNewDef = LTRIM(@NewDef);
SET @CreatePrefix = N'CREATE PROCEDURE';
SET @CreateAlterPrefix = N'CREATE OR ALTER PROCEDURE';
SET @AlterPrefix = N'ALTER PROCEDURE';

/* Normalize the installed definition to an executable ALTER-safe definition. */
IF UPPER(LEFT(@TrimmedNewDef, LEN(@CreateAlterPrefix))) = @CreateAlterPrefix
BEGIN
    /* CREATE OR ALTER is already safe. Keep a real statement in this branch. */
    SET @NewDef = @NewDef;
END
ELSE IF UPPER(LEFT(@TrimmedNewDef, LEN(@CreatePrefix))) = @CreatePrefix
BEGIN
    SET @NewDef = STUFF
    (
        @NewDef,
        CHARINDEX(@CreatePrefix, UPPER(@NewDef)),
        LEN(@CreatePrefix),
        @AlterPrefix
    );
END
ELSE IF UPPER(LEFT(@TrimmedNewDef, LEN(@AlterPrefix))) = @AlterPrefix
BEGIN
    /* Already ALTER PROCEDURE. Keep a real statement in this branch. */
    SET @NewDef = @NewDef;
END
ELSE
BEGIN
    RAISERROR('Prefix procedure tidak dikenali. Patch dihentikan untuk keamanan.', 16, 1);
    RETURN;
END;

EXEC sys.sp_executesql @NewDef;

IF CHARINDEX
   (
       @PatchMarker,
       OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp', N'P'))
   ) = 0
BEGIN
    RAISERROR('Patch 13 dieksekusi tetapi marker tidak ditemukan sesudah ALTER.', 16, 1);
    RETURN;
END;

PRINT 'OK - Patch 13 Rev.2 terpasang. Standard SiteRef detail CSV dinormalisasi sebelum one-hit processing.';
