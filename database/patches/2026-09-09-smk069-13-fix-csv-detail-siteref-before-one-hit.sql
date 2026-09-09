/* =============================================================================
   SMK069 - Patch 13 Rev.3 - Fix CSV detail SiteRef before CSV -> CO one-hit
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Object  : dbo.SMK069RunCsvTestBatchSp
   Purpose : Fix POS-402 when CSV parser shows detail rows on the form but the
             one-hit CSV -> Customer Order procedure cannot see them because
             ue_SMK069_pos_csv_upload_mst.SiteRef is NULL/blank or not aligned
             with the active Mongoose site.

   REV.3
   -----
   - Fixes Apply Database error:
         Prefix procedure tidak dikenali.
   - Does not assume the installed module starts exactly with CREATE PROCEDURE.
   - Supports CREATE PROCEDURE, CREATE PROC, CREATE OR ALTER PROCEDURE,
     CREATE OR ALTER PROC, ALTER PROCEDURE and ALTER PROC, including whitespace.
   - Locates the actual PROC/PROCEDURE token immediately before
     SMK069RunCsvTestBatchSp and rewrites only that module header to
     ALTER PROCEDURE.
   - One executable batch; no GO separator.

   IMPORTANT: SiteRef vs siteref
   -----------------------------
   SiteRef = standard Mongoose site ownership column used by site-aware SQL.
   siteref = business/source field parsed from the CSV and may legitimately be
             blank when the CSV does not provide site/site_ref/siteref.

   Patch 13 fixes SiteRef because that is the field used by the one-hit
   preflight. It does not require the CSV business field siteref to be populated.
   ============================================================================= */

SET NOCOUNT ON;

DECLARE
    @ObjectId       INT,
    @Definition     NVARCHAR(MAX),
    @Needle         NVARCHAR(400),
    @InsertPos      INT,
    @PatchMarker    NVARCHAR(200),
    @Snippet        NVARCHAR(MAX),
    @NewDef         NVARCHAR(MAX),
    @UpperDef       NVARCHAR(MAX),
    @NamePos        INT,
    @ProcPos        INT,
    @ProcLen        INT,
    @BeforeName     NVARCHAR(MAX),
    @RevBeforeName  NVARCHAR(MAX),
    @RevIdx         INT,
    @WindowStart    INT,
    @PrefixWindow   NVARCHAR(200),
    @RevPrefix      NVARCHAR(200),
    @CreateRev      INT,
    @AlterRev       INT,
    @CreatePos      INT,
    @AlterPos       INT,
    @HeaderStart    INT,
    @HeaderEnd      INT;

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
SET @UpperDef = UPPER(@NewDef);

/* Find the exact procedure name in the installed definition. */
SET @NamePos = CHARINDEX(N'SMK069RUNCSVTESTBATCHSP', @UpperDef);

IF @NamePos = 0
BEGIN
    RAISERROR('Nama SMK069RunCsvTestBatchSp tidak ditemukan di definition. Patch dihentikan.', 16, 1);
    RETURN;
END;

SET @BeforeName = LEFT(@UpperDef, @NamePos - 1);
SET @RevBeforeName = REVERSE(@BeforeName);

/* Prefer PROCEDURE; fall back to PROC. */
SET @RevIdx = CHARINDEX(REVERSE(N'PROCEDURE'), @RevBeforeName);
IF @RevIdx > 0
BEGIN
    SET @ProcLen = LEN(N'PROCEDURE');
    SET @ProcPos = LEN(@BeforeName) - @RevIdx - @ProcLen + 2;
END
ELSE
BEGIN
    SET @RevIdx = CHARINDEX(REVERSE(N'PROC'), @RevBeforeName);
    IF @RevIdx = 0
    BEGIN
        RAISERROR('Token PROC/PROCEDURE tidak ditemukan sebelum nama procedure.', 16, 1);
        RETURN;
    END;

    SET @ProcLen = LEN(N'PROC');
    SET @ProcPos = LEN(@BeforeName) - @RevIdx - @ProcLen + 2;
END;

/* Search only near PROC/PROCEDURE for CREATE/ALTER. */
SET @WindowStart = CASE WHEN @ProcPos > 80 THEN @ProcPos - 80 ELSE 1 END;
SET @PrefixWindow = SUBSTRING(@UpperDef, @WindowStart, @ProcPos - @WindowStart);
SET @RevPrefix = REVERSE(@PrefixWindow);
SET @CreateRev = CHARINDEX(REVERSE(N'CREATE'), @RevPrefix);
SET @AlterRev  = CHARINDEX(REVERSE(N'ALTER'),  @RevPrefix);
SET @CreatePos = CASE WHEN @CreateRev > 0 THEN @ProcPos - @CreateRev - LEN(N'CREATE') + 1 ELSE 0 END;
SET @AlterPos  = CASE WHEN @AlterRev  > 0 THEN @ProcPos - @AlterRev  - LEN(N'ALTER')  + 1 ELSE 0 END;

/* CREATE OR ALTER: replace from CREATE. CREATE only: from CREATE.
   ALTER only: from ALTER. */
IF @CreatePos > 0 AND @AlterPos > @CreatePos AND (@ProcPos - @CreatePos) <= 40
    SET @HeaderStart = @CreatePos;
ELSE IF @AlterPos > 0 AND (@ProcPos - @AlterPos) <= 25
    SET @HeaderStart = @AlterPos;
ELSE IF @CreatePos > 0 AND (@ProcPos - @CreatePos) <= 25
    SET @HeaderStart = @CreatePos;
ELSE
BEGIN
    RAISERROR('CREATE/ALTER header tidak ditemukan dekat PROC/PROCEDURE. Patch dihentikan.', 16, 1);
    RETURN;
END;

SET @HeaderEnd = @ProcPos + @ProcLen - 1;
SET @NewDef = STUFF(@NewDef, @HeaderStart, @HeaderEnd - @HeaderStart + 1, N'ALTER PROCEDURE');

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

PRINT 'OK - Patch 13 Rev.3 terpasang. Standard SiteRef detail CSV dinormalisasi sebelum one-hit processing.';
