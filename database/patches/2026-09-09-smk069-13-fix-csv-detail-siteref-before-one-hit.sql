/* =============================================================================
   SMK069 - Patch 13 - Fix CSV detail SiteRef before CSV -> CO one-hit
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Object  : dbo.SMK069RunCsvTestBatchSp
   Purpose : Fix POS-402 when CSV parser shows detail rows on the form but the
             one-hit CSV -> Customer Order procedure cannot see them because
             ue_SMK069_pos_csv_upload_mst.SiteRef is NULL/blank or not aligned
             with the active Mongoose site.

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

   SAFE BEHAVIOR
   -------------
   The injected normalization runs only after the batch header has already been
   resolved in the active site context. It updates detail rows for the same
   batch_id only when SiteRef is NULL/blank/different, then the original stored
   procedure continues unchanged.

   Designed for Infor Apply Database: one executable batch, no GO separator.
   ============================================================================= */

SET NOCOUNT ON;

DECLARE
    @ObjectId    INT,
    @Definition  NVARCHAR(MAX),
    @Needle      NVARCHAR(400),
    @InsertPos   INT,
    @PatchMarker NVARCHAR(200),
    @Snippet     NVARCHAR(MAX),
    @NewDef      NVARCHAR(MAX);

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
    /* The CSV parser historically did not explicitly populate the standard
       Mongoose SiteRef column on detail rows. Normalize it here only for a
       batch header that belongs to the active site. */
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

/* OBJECT_DEFINITION normally returns CREATE/ALTER text. Force an ALTER-safe
   prefix so this remains idempotent for an existing procedure. */
IF UPPER(LEFT(LTRIM(@NewDef), 16)) = N'CREATE PROCEDURE'
BEGIN
    SET @NewDef = STUFF(
        @NewDef,
        CHARINDEX(N'CREATE PROCEDURE', UPPER(@NewDef)),
        LEN(N'CREATE PROCEDURE'),
        N'ALTER PROCEDURE'
    );
END
ELSE IF UPPER(LEFT(LTRIM(@NewDef), 22)) = N'CREATE OR ALTER PROCEDURE'
BEGIN
    /* supported as-is */
END
ELSE IF CHARINDEX(N'ALTER PROCEDURE', UPPER(@NewDef)) = 0
BEGIN
    RAISERROR('Prefix procedure tidak dikenali. Patch dihentikan untuk keamanan.', 16, 1);
    RETURN;
END;

EXEC sys.sp_executesql @NewDef;

IF CHARINDEX(
       @PatchMarker,
       OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp', N'P'))
   ) = 0
BEGIN
    RAISERROR('Patch 13 dieksekusi tetapi marker tidak ditemukan sesudah ALTER.', 16, 1);
    RETURN;
END;

PRINT 'OK - SMK069RunCsvTestBatchSp sekarang menormalisasi SiteRef detail CSV sebelum one-hit processing.';
