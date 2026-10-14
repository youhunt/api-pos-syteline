/* =============================================================================
   SMK069 - Patch 37 - Urgent flag untuk jalur CSV (form SMK POS CSV TO BLANKET CO)
   -----------------------------------------------------------------------------
   Date    : 2026-10-14
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY
   Depends : Patch 36 (Core + Process sudah membaca Is_Urgent / Urgent Remark)
   Objects : dbo.ue_SMK069_pos_csv_upload_mst   (tambah kolom)
             dbo.SMK069ImportCsvFileSp          (diedit in-place)
             dbo.SMK069RunCsvTestBatchSp        (diedit in-place)

   KEBUTUHAN
   ---------
   Selain Postman, pengujian juga memakai form "SMK POS CSV TO BLANKET CO".
   Alur form itu:

     file CSV -> SMK069ImportCsvFileSp -> ue_SMK069_pos_csv_upload_mst
              -> SMK069RunCsvTestBatchSp (bentuk JSON)
              -> SMK069ReceivePosSalesJsonSp -> Core (Patch 36) -> co_bln_mst

   Patch 36 sudah membaca urgent dari JSON, tetapi JSON dari CSV belum membawa
   field itu. Patch ini menambahkannya di dua ujung jalur CSV:

     Header CSV (opsional)      Detail CSV                       JSON ke Receive
     ------------------------   ------------------------------   -----------------
     is_urgent  (isurgent)      is_urgent      INT  def 0        "is_urgent"
     urgent_remark              urgent_remark  NVARCHAR(255)     "urgent_remark"
       (Urgent Remark,
        urgentremark)

   Aturan sama dengan payload API (keputusan bisnis 14 Okt 2026):
     - Is_Urgent 1 -> 1. SELAIN 1 (kosong, 0, Y, 2, teks apa pun) -> 0, tanpa
       error dan tanpa kode POS-xxx baru.
     - Urgent Remark opsional, kosong disimpan NULL, dipotong 255 karakter.
     - Kolom CSV bersifat opsional: CSV lama tanpa kolom ini tetap diterima
       dan hasilnya Normal (0 / NULL).
     - Nama header dibaca tanpa membedakan huruf besar/kecil; spasi dan tanda
       minus dianggap garis bawah ("Urgent Remark" = urgent_remark).

   MENGAPA DIEDIT IN-PLACE
   -----------------------
   Sama dengan Patch 36: source repo bisa tertinggal dari tenant, jadi patch
   membaca OBJECT_DEFINITION, menyisipkan blok PATCH-37 pada anchor teks yang
   harus ada TEPAT sekali, lalu men-CREATE OR ALTER ulang.
     - Semua anchor diperiksa DULU untuk semua object. Jika ada yang tidak
       cocok: patch BERHENTI dengan THROW dan tidak mengubah procedure apa pun
       (kolom tabel boleh sudah bertambah; aman dan idempotent).
     - Re-runnable: object yang sudah memuat marker PATCH-37 dilewati.
     - Perubahan procedure dibungkus satu transaksi.
     - Signature procedure TIDAK berubah, metadata IDO method tidak berubah.

   SETELAH PATCH INI (metadata Mongoose, bukan SQL)
   ------------------------------------------------
     1. Resynchronize IDO ue_SMK069PosCsvUpload agar property IsUrgent dan
        UrgentRemark muncul.
     2. Tambahkan dua kolom grid pada form SMK POS CSV TO BLANKET CO
        (file form XML tersedia di forms/csv-to-co/exports).
     Lihat docs/csv-to-co/50-urgent-flag.md bagian "Jalur CSV".

   CATATAN
   -------
     - Sebelum menjalankan, script-out dulu kedua procedure dari tenant sebagai
       cadangan rollback.

   Apply Database compatible: one executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* =============================================================================
   0. PRECHECK
   ============================================================================= */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_upload_mst', N'U') IS NULL
    THROW 510380, N'[PATCH-37] Tabel detail CSV ue_SMK069_pos_csv_upload_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.SMK069ImportCsvFileSp', N'P') IS NULL
    THROW 510381, N'[PATCH-37] Procedure SMK069ImportCsvFileSp tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp', N'P') IS NULL
    THROW 510382, N'[PATCH-37] Procedure SMK069RunCsvTestBatchSp tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'P') IS NULL
    THROW 510383, N'[PATCH-37] Procedure SMK069ReceivePosSalesJsonCoreSp tidak ditemukan.', 1;

/* Tanpa Patch 36, nilai urgent dari CSV akan hilang diam-diam di Core. */
IF CHARINDEX
   (
       N'INTO #SMK069Urgent',
       COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')), N'')
   ) = 0
    THROW 510384, N'[PATCH-37] Patch 36 belum terpasang di SMK069ReceivePosSalesJsonCoreSp. Jalankan Patch 36 dulu, lalu jalankan ulang patch ini.', 1;

/* =============================================================================
   1. KOLOM DETAIL CSV (idempotent)
      Tidak ada statement statis yang mereferensikan kolom baru di batch ini;
      semua pemakaian kolom baru berada di dalam procedure yang dibuat lewat
      sp_executesql.
   ============================================================================= */
IF COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'is_urgent') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_csv_upload_mst
        ADD is_urgent INT NOT NULL
            CONSTRAINT DF_ue_SMK069_pos_csv_upload_is_urgent DEFAULT (0) WITH VALUES;
END;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'urgent_remark') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_csv_upload_mst
        ADD urgent_remark NVARCHAR(255) NULL;
END;

/* =============================================================================
   2. DAFTAR EDIT (anchor -> pengganti)
      Dibangkitkan dari satu sumber yang sama dengan edit pada file canonical
      di repo, sehingga hasil patch = isi file canonical.
   ============================================================================= */
DECLARE @Edit TABLE
(
    edit_id        INT IDENTITY(1,1) PRIMARY KEY,
    obj_name       SYSNAME       NOT NULL,
    label          NVARCHAR(80)  NOT NULL,
    expected_count INT           NOT NULL,
    anchor         NVARCHAR(MAX) NOT NULL,
    repl           NVARCHAR(MAX) NOT NULL
);

DECLARE
    @Anchor NVARCHAR(MAX),
    @Repl   NVARCHAR(MAX);

/* dbo.SMK069ImportCsvFileSp :: I1 alias header urgent */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'THEN N''is_peak_season''';
SET @Repl = N'';
SET @Repl = @Repl + N'THEN N''is_peak_season''
                    WHEN n.normalized IN (N''is_urgent'', N''isurgent'')
                        THEN N''is_urgent''            /* PATCH-37 */
                    WHEN n.normalized IN (N''urgent_remark'', N''urgentremark'')
                        THEN N''urgent_remark''        /* PATCH-37 */';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ImportCsvFileSp', N'I1 alias header urgent', 1, @Anchor, @Repl);

/* dbo.SMK069ImportCsvFileSp :: I2 tabel penampung urgent */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'DECLARE @Fields TABLE';
SET @Repl = N'';
SET @Repl = @Repl + N'/* PATCH-37 Urgent flag: nilai urgent per baris data, ditulis ke detail CSV sebelum COMMIT. */
    DECLARE @ParsedUrgent TABLE
    (
        row_no        INT NOT NULL PRIMARY KEY,
        is_urgent     INT NOT NULL,
        urgent_remark NVARCHAR(255) NULL
    );

    DECLARE @Fields TABLE';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ImportCsvFileSp', N'I2 tabel penampung urgent', 1, @Anchor, @Repl);

/* dbo.SMK069ImportCsvFileSp :: I3 variabel urgent */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'@RawIsPeakSeason NVARCHAR(MAX),';
SET @Repl = N'';
SET @Repl = @Repl + N'@RawIsPeakSeason NVARCHAR(MAX),
        @RawIsUrgent    NVARCHAR(MAX),   /* PATCH-37 */
        @RawUrgentRemark NVARCHAR(MAX),  /* PATCH-37 */
        @IsUrgent       INT,             /* PATCH-37 */';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ImportCsvFileSp', N'I3 variabel urgent', 1, @Anchor, @Repl);

/* dbo.SMK069ImportCsvFileSp :: I4 reset variabel urgent */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'SET @RawIsPeakSeason = NULL;';
SET @Repl = N'';
SET @Repl = @Repl + N'SET @RawIsPeakSeason = NULL;
        SET @RawIsUrgent = NULL;         /* PATCH-37 */
        SET @RawUrgentRemark = NULL;     /* PATCH-37 */
        SET @IsUrgent = 0;               /* PATCH-37 */';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ImportCsvFileSp', N'I4 reset variabel urgent', 1, @Anchor, @Repl);

/* dbo.SMK069ImportCsvFileSp :: I5 ambil kolom urgent */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'N''is_peak_season'' THEN f.field_value END),';
SET @Repl = N'';
SET @Repl = @Repl + N'N''is_peak_season'' THEN f.field_value END),
            @RawIsUrgent     = MAX(CASE WHEN h.canonical_name = N''is_urgent''     THEN f.field_value END),  /* PATCH-37 */
            @RawUrgentRemark = MAX(CASE WHEN h.canonical_name = N''urgent_remark'' THEN f.field_value END),  /* PATCH-37 */';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ImportCsvFileSp', N'I5 ambil kolom urgent', 1, @Anchor, @Repl);

/* dbo.SMK069ImportCsvFileSp :: I6 hitung urgent per baris */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'IF @RawCustNum IS NULL';
SET @Repl = N'';
SET @Repl = @Repl + N'/* PATCH-37 Urgent flag: 1 / "1" -> 1, selain itu (kosong, 0, Y, 2, teks) -> 0 tanpa error.
           Remark opsional, dipotong maksimal 255 karakter. */
        SET @IsUrgent = CASE WHEN TRY_CONVERT(DECIMAL(18,4), @RawIsUrgent) = 1 THEN 1 ELSE 0 END;

        INSERT INTO @ParsedUrgent (row_no, is_urgent, urgent_remark)
        VALUES (@DataRow, @IsUrgent, LEFT(NULLIF(@RawUrgentRemark, N''''), 255));

        IF @RawCustNum IS NULL';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ImportCsvFileSp', N'I6 hitung urgent per baris', 1, @Anchor, @Repl);

/* dbo.SMK069ImportCsvFileSp :: I7 simpan urgent ke detail CSV */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'COMMIT TRANSACTION;';
SET @Repl = N'';
SET @Repl = @Repl + N'/* PATCH-37 Urgent flag: simpan ke detail CSV (dibaca SMK069RunCsvTestBatchSp). */
        UPDATE d
        SET
            d.is_urgent = u.is_urgent,
            d.urgent_remark = u.urgent_remark
        FROM dbo.ue_SMK069_pos_csv_upload_mst AS d
        INNER JOIN @ParsedUrgent AS u
          ON u.row_no = d.row_no
        WHERE d.batch_id = @BatchId;

        COMMIT TRANSACTION;';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ImportCsvFileSp', N'I7 simpan urgent ke detail CSV', 1, @Anchor, @Repl);

/* dbo.SMK069RunCsvTestBatchSp :: R1 urgent ke JSON */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'CONVERT(NVARCHAR(8), @Site) AS siteref,';
SET @Repl = N'';
SET @Repl = @Repl + N'ISNULL(d.is_urgent, 0) AS is_urgent,                          /* PATCH-37: urgent CSV payload */
            NULLIF(LTRIM(RTRIM(d.urgent_remark)), N'''') AS urgent_remark,  /* PATCH-37 */
            CONVERT(NVARCHAR(8), @Site) AS siteref,';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069RunCsvTestBatchSp', N'R1 urgent ke JSON', 1, @Anchor, @Repl);


/* =============================================================================
   3. FASE A - SUSUN DEFINISI BARU (belum mengubah object apa pun)
   ============================================================================= */
DECLARE @Plan TABLE
(
    obj_name SYSNAME       NOT NULL PRIMARY KEY,
    new_def  NVARCHAR(MAX) NOT NULL,
    skip_it  BIT           NOT NULL
);

DECLARE
    @ObjName  SYSNAME,
    @Def      NVARCHAR(MAX),
    @EditId   INT,
    @Label    NVARCHAR(80),
    @Expected INT,
    @Found    BIGINT,
    @HeaderOk BIT,
    @From     INT,
    @Probe    NVARCHAR(200),
    @Pos      INT,
    @Msg      NVARCHAR(2000);

DECLARE ObjCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT obj_name
    FROM @Edit
    GROUP BY obj_name
    ORDER BY MIN(edit_id);

OPEN ObjCursor;
FETCH NEXT FROM ObjCursor INTO @ObjName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Def = OBJECT_DEFINITION(OBJECT_ID(@ObjName));

    IF @Def IS NULL
    BEGIN
        SET @Msg = N'[PATCH-37] Definisi ' + @ObjName + N' tidak dapat dibaca (permission atau encrypted).';
        THROW 510385, @Msg, 1;
    END;

    /* Samakan akhir baris (CRLF/CR -> LF) supaya anchor tidak bergantung pada format file. */
    SET @Def = REPLACE(REPLACE(@Def, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

    IF CHARINDEX(N'PATCH-37', @Def COLLATE Latin1_General_100_BIN2) > 0
    BEGIN
        PRINT N'[PATCH-37] SKIP (sudah terpasang): ' + @ObjName;

        INSERT INTO @Plan (obj_name, new_def, skip_it)
        VALUES (@ObjName, N'', 1);
    END
    ELSE
    BEGIN
        SET @EditId = (SELECT MIN(edit_id) FROM @Edit WHERE obj_name = @ObjName);

        WHILE @EditId IS NOT NULL
        BEGIN
            SELECT
                @Label    = e.label,
                @Expected = e.expected_count,
                @Anchor   = e.anchor,
                @Repl     = e.repl
            FROM @Edit AS e
            WHERE e.edit_id = @EditId;

            SET @Anchor = REPLACE(REPLACE(@Anchor, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));
            SET @Repl   = REPLACE(REPLACE(@Repl,   NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

            /* Hitung kemunculan anchor (perbandingan biner = persis sama). */
            SET @Found =
                (
                    DATALENGTH(@Def)
                    - DATALENGTH(REPLACE(@Def COLLATE Latin1_General_100_BIN2, @Anchor, N''))
                )
                / NULLIF(DATALENGTH(@Anchor), 0);

            IF ISNULL(@Found, -1) <> @Expected
            BEGIN
                SET @Msg =
                    N'[PATCH-37] Anchor "' + @Label + N'" pada ' + @ObjName
                    + N' ditemukan ' + CONVERT(NVARCHAR(20), ISNULL(@Found, -1))
                    + N' kali (seharusnya ' + CONVERT(NVARCHAR(20), @Expected)
                    + N'). Definisi di tenant berbeda dari repo. Patch dibatalkan, procedure tidak diubah. Lihat docs/csv-to-co/50-urgent-flag.md bagian Jalur CSV.';
                THROW 510386, @Msg, 1;
            END;

            SET @Def = REPLACE(@Def COLLATE Latin1_General_100_BIN2, @Anchor, @Repl);

            SET @EditId =
                (
                    SELECT MIN(e.edit_id)
                    FROM @Edit AS e
                    WHERE e.obj_name = @ObjName
                      AND e.edit_id > @EditId
                );
        END;

        /* Pastikan header bisa dieksekusi ulang. Diterima: CREATE OR ALTER PROC[EDURE],
           ALTER PROC[EDURE], atau CREATE PROC[EDURE] (diubah menjadi ALTER).
           Spasi / tab / baris baru di antara kata diabaikan; posisi dicari di teks asli. */
        SET @HeaderOk = 0;
        SET @From = 1;

        WHILE @HeaderOk = 0 AND @From < 30000
        BEGIN
            SET @Pos = CHARINDEX(N'CREATE', @Def COLLATE Latin1_General_100_CI_AS, @From);

            IF @Pos = 0 OR @Pos >= 30000
                BREAK;

            SET @Probe = REPLACE(REPLACE(REPLACE(SUBSTRING(@Def, @Pos + 6, 80), NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ');

            IF LEFT(@Probe, 1) = N' '
            BEGIN
                SET @Probe = UPPER(LTRIM(@Probe));

                IF LEFT(@Probe, 3) = N'OR '
                BEGIN
                    SET @HeaderOk = 1;   /* CREATE OR ALTER: sudah bisa dieksekusi apa adanya */
                END
                ELSE IF LEFT(@Probe, 5) = N'PROC ' OR LEFT(@Probe, 10) = N'PROCEDURE '
                BEGIN
                    SET @Def = STUFF(@Def, @Pos, 6, N'ALTER');
                    SET @HeaderOk = 1;
                END;
            END;

            SET @From = @Pos + 6;
        END;

        SET @From = 1;

        WHILE @HeaderOk = 0 AND @From < 30000
        BEGIN
            SET @Pos = CHARINDEX(N'ALTER', @Def COLLATE Latin1_General_100_CI_AS, @From);

            IF @Pos = 0 OR @Pos >= 30000
                BREAK;

            SET @Probe = REPLACE(REPLACE(REPLACE(SUBSTRING(@Def, @Pos + 5, 80), NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ');

            IF LEFT(@Probe, 1) = N' '
            BEGIN
                SET @Probe = UPPER(LTRIM(@Probe));

                IF LEFT(@Probe, 5) = N'PROC ' OR LEFT(@Probe, 10) = N'PROCEDURE '
                    SET @HeaderOk = 1;
            END;

            SET @From = @Pos + 5;
        END;

        IF @HeaderOk = 0
        BEGIN
            SET @Msg =
                N'[PATCH-37] Header CREATE/ALTER PROC[EDURE] tidak dikenali pada ' + @ObjName
                + N'. Awal definisi: '
                + LEFT(REPLACE(REPLACE(REPLACE(@Def, NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' '), 160);
            THROW 510387, @Msg, 1;
        END;

        INSERT INTO @Plan (obj_name, new_def, skip_it)
        VALUES (@ObjName, @Def, 0);
    END;

    FETCH NEXT FROM ObjCursor INTO @ObjName;
END;

CLOSE ObjCursor;
DEALLOCATE ObjCursor;

/* =============================================================================
   4. FASE B - TERAPKAN (satu transaksi; XACT_ABORT ON => rollback otomatis)
   ============================================================================= */
BEGIN TRANSACTION;

DECLARE PlanCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT obj_name, new_def
    FROM @Plan
    WHERE skip_it = 0
    ORDER BY obj_name;

OPEN PlanCursor;
FETCH NEXT FROM PlanCursor INTO @ObjName, @Def;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sys.sp_executesql @Def;
    PRINT N'[PATCH-37] OK diperbarui: ' + @ObjName;

    FETCH NEXT FROM PlanCursor INTO @ObjName, @Def;
END;

CLOSE PlanCursor;
DEALLOCATE PlanCursor;

COMMIT TRANSACTION;

/* =============================================================================
   5. POST-CHECK
   ============================================================================= */
DECLARE
    @ImpDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ImportCsvFileSp')), N''),
    @RunDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069RunCsvTestBatchSp')), N'');

IF COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'is_urgent') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_csv_upload_mst', N'urgent_remark') IS NULL
    THROW 510388, N'[PATCH-37] Kolom is_urgent/urgent_remark belum ada di ue_SMK069_pos_csv_upload_mst.', 1;

IF CHARINDEX(N'@ParsedUrgent', @ImpDef) = 0
   OR CHARINDEX(N'd.is_urgent = u.is_urgent', @ImpDef) = 0
    THROW 510389, N'[PATCH-37] Blok urgent belum terpasang di SMK069ImportCsvFileSp.', 1;

IF CHARINDEX(N'AS urgent_remark', @RunDef) = 0
    THROW 510390, N'[PATCH-37] JSON urgent belum terpasang di SMK069RunCsvTestBatchSp.', 1;

PRINT N'[PATCH-37] SUCCESS - kolom is_urgent / urgent_remark pada CSV mengalir sampai Receive.';
