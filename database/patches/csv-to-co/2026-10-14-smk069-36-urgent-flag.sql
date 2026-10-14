/* =============================================================================
   SMK069 - Patch 36 - Urgent flag (Is_Urgent + Urgent Remark)
   -----------------------------------------------------------------------------
   Date    : 2026-10-14
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY
   Objects : dbo.ue_SMK069_pos_sales_inbound_mst   (tambah kolom)
             dbo.ue_SMK069_temp_sales_mst          (tambah kolom)
             dbo.SMK069ReceivePosSalesJsonCoreSp   (diedit in-place)
             dbo.SMK069ProcessCustomerOrderSp      (diedit in-place)

   KEBUTUHAN BISNIS
   ----------------
   User perlu tahu apakah sebuah order urgent atau tidak. Dua field baru:

     Payload API Sales        Staging (inbound + temp)     Blanket line (co_bln_mst, UET)
     ----------------------   --------------------------   -------------------------------
     "Is_Urgent"      0/1     is_urgent      INT  def 0    Uf_SMK069_is_urgent      (int)
     "Urgent Remark"  teks    urgent_remark  NVARCHAR(255) Uf_SMK069_urgent_remark   (nvarchar 255)

   Catatan kontrak payload:
     - Key "Urgent Remark" memakai SPASI (sesuai contoh payload dari bisnis).
       Key dibaca tanpa membedakan huruf besar/kecil. Alias yang juga diterima:
       is_urgent, isurgent, urgent_remark, urgent remark, urgentremark.
     - Is_Urgent: 1 / "1" -> 1. SELAIN 1 (0, kosong, tidak ada key, true, "Y", 2,
       teks apa pun) -> 0, tanpa error dan tanpa kode POS-xxx baru (keputusan
       bisnis 14 Okt 2026). Field bersifat OPSIONAL: payload lama tanpa field ini
       tetap diterima dan dianggap tidak urgent.
     - Urgent Remark TIDAK wajib walau Is_Urgent = 1 (remark berasal dari POS).
       Kosong disimpan sebagai NULL, dipotong maksimal 255 karakter.

   MENGAPA PATCH INI MENGEDIT DEFINISI YANG SEDANG AKTIF
   -----------------------------------------------------
   Per 12 Okt 2026 source canonical SMK069ReceivePosSalesJsonCoreSp di repo
   TERTINGGAL dari TRN (retry BatchId yang sama + history). Menimpa dengan
   salinan repo akan menghapus perubahan TRN tersebut. Karena itu patch ini
   membaca OBJECT_DEFINITION dari tenant, menyisipkan blok PATCH-36 pada anchor
   teks yang sudah dipastikan ada TEPAT sekali, lalu men-CREATE OR ALTER ulang.

     - Semua anchor diperiksa DULU untuk semua object. Jika ada anchor yang tidak
       ditemukan / ditemukan lebih dari sekali: patch BERHENTI dengan THROW dan
       tidak mengubah procedure apa pun (kolom tabel boleh sudah bertambah; itu
       aman dan idempotent).
     - Re-runnable: object yang sudah memuat marker PATCH-36 dilewati. Bila blok
       PATCH-36 versi pertama (remark 250, true dianggap urgent) sudah terpasang,
       blok itu diperbarui otomatis ke versi ini (edit upgrade U1-U3) dan kolom
       urgent_remark dilebarkan ke 255.
     - Perubahan procedure dibungkus satu transaksi.
     - Signature procedure TIDAK berubah, jadi metadata IDO method tidak berubah.
     - ue_SMK069_pos_sales_inbound_mapping_view (milik Eva / SMK) TIDAK diubah.

   PRASYARAT (di luar patch ini)
   -----------------------------
   UET pada co_bln_mst harus sudah dibuat dan Impact Schema sudah dijalankan:
     Uf_SMK069_is_urgent       int
     Uf_SMK069_urgent_remark   nvarchar(255)
   Lihat docs/csv-to-co/50-urgent-flag.md. Tanpa kolom itu, patch berhenti di
   precheck sebelum mengubah apa pun.

   CATATAN
   -------
     - CSV upload (ue_SMK069_pos_csv_upload_mst) TIDAK diubah: kebutuhan ini
       hanya untuk payload API Sales. JSON dari CSV tidak membawa field urgent,
       sehingga hasilnya Normal (0 / NULL).
     - Tabel history inbound (ue_SMK069_pos_sales_inbound_hist) TIDAK diubah.
     - Sebelum menjalankan, script-out dulu kedua procedure dari tenant sebagai
       cadangan rollback.

   Apply Database compatible: one executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* =============================================================================
   0. PRECHECK
   ============================================================================= */
IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    THROW 510360, N'[PATCH-36] Tabel inbound ue_SMK069_pos_sales_inbound_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_temp_sales_mst', N'U') IS NULL
    THROW 510361, N'[PATCH-36] Tabel temp ue_SMK069_temp_sales_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.co_bln_mst', N'U') IS NULL
    THROW 510362, N'[PATCH-36] Tabel co_bln_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'P') IS NULL
    THROW 510363, N'[PATCH-36] Procedure SMK069ReceivePosSalesJsonCoreSp tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp', N'P') IS NULL
    THROW 510364, N'[PATCH-36] Procedure SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.co_bln_mst', N'Uf_SMK069_is_urgent') IS NULL
   OR COL_LENGTH(N'dbo.co_bln_mst', N'Uf_SMK069_urgent_remark') IS NULL
    THROW 510365, N'[PATCH-36] UET co_bln_mst belum ada (Uf_SMK069_is_urgent dan/atau Uf_SMK069_urgent_remark). Buat UET + jalankan Impact Schema dulu, lihat docs/csv-to-co/50-urgent-flag.md, lalu jalankan ulang patch ini.', 1;

DECLARE @RemarkBytes INT = COL_LENGTH(N'dbo.co_bln_mst', N'Uf_SMK069_urgent_remark');

/* COL_LENGTH = byte; nvarchar(255) = 510 byte; nvarchar(max) = -1. */
IF @RemarkBytes <> -1 AND @RemarkBytes < 510
    THROW 510366, N'[PATCH-36] Uf_SMK069_urgent_remark harus nvarchar(255) atau lebih besar agar remark payload tidak terpotong.', 1;

/* =============================================================================
   1. KOLOM STAGING (idempotent)
      Tidak ada statement statis yang mereferensikan kolom baru di batch ini;
      semua pemakaian kolom baru berada di dalam procedure yang dibuat lewat
      sp_executesql.
   ============================================================================= */
IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'is_urgent') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_sales_inbound_mst
        ADD is_urgent INT NOT NULL
            CONSTRAINT DF_ue_SMK069_pos_sales_inbound_is_urgent DEFAULT (0) WITH VALUES;
END;

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'urgent_remark') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_pos_sales_inbound_mst
        ADD urgent_remark NVARCHAR(255) NULL;
END
ELSE IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'urgent_remark') BETWEEN 1 AND 509
BEGIN
    /* Patch 36 versi pertama membuat kolom ini 250; lebarkan ke 255. */
    ALTER TABLE dbo.ue_SMK069_pos_sales_inbound_mst
        ALTER COLUMN urgent_remark NVARCHAR(255) NULL;
END;

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'is_urgent') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_temp_sales_mst
        ADD is_urgent INT NOT NULL
            CONSTRAINT DF_ue_SMK069_temp_sales_is_urgent DEFAULT (0) WITH VALUES;
END;

IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'urgent_remark') IS NULL
BEGIN
    ALTER TABLE dbo.ue_SMK069_temp_sales_mst
        ADD urgent_remark NVARCHAR(255) NULL;
END
ELSE IF COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'urgent_remark') BETWEEN 1 AND 509
BEGIN
    /* Patch 36 versi pertama membuat kolom ini 250; lebarkan ke 255. */
    ALTER TABLE dbo.ue_SMK069_temp_sales_mst
        ALTER COLUMN urgent_remark NVARCHAR(255) NULL;
END;

/* =============================================================================
   2. DAFTAR EDIT (anchor -> pengganti)
      Teks di bawah dibangkitkan dari satu sumber yang sama dengan edit pada
      file canonical di repo, sehingga hasil patch = isi file canonical.
      is_upgrade = 0 : edit pemasangan awal (anchor harus ada TEPAT expected_count kali)
      is_upgrade = 1 : edit upgrade blok PATCH-36 versi pertama -> versi ini;
                       dilewati bila teks lama sudah tidak ada
   ============================================================================= */
DECLARE @Edit TABLE
(
    edit_id        INT IDENTITY(1,1) PRIMARY KEY,
    obj_name       SYSNAME       NOT NULL,
    label          NVARCHAR(80)  NOT NULL,
    expected_count INT           NOT NULL,
    is_upgrade     BIT           NOT NULL,
    anchor         NVARCHAR(MAX) NOT NULL,
    repl           NVARCHAR(MAX) NOT NULL
);

DECLARE
    @Anchor NVARCHAR(MAX),
    @Repl   NVARCHAR(MAX);

/* dbo.SMK069ReceivePosSalesJsonCoreSp :: C1 persist urgent ke inbound */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'3. Snapshot BUSINESS SOURCE from mapping view';
SET @Repl = N'';
SET @Repl = @Repl + N'PATCH-36 Urgent flag - baca Is_Urgent / Urgent Remark dari raw_json.
           Nama key dibaca tanpa membedakan huruf besar/kecil dan spasi pinggir
           diabaikan. Alias yang diterima:
             Is_Urgent      : is_urgent, isurgent
             Urgent Remark  : urgent_remark, urgent remark, urgentremark
           Is_Urgent 1 / "1" -> 1, selain itu (termasuk true, "Y", 2) -> 0 (default Normal).
           Disimpan ke inbound SEBELUM mapping view (konsisten dengan Peak Season).
           Mapping view milik Eva/SMK TIDAK diubah.
           ============================================================= */
        SELECT
            i.inbound_id,
            MAX(CASE WHEN nk.norm_key IN (N''is_urgent'', N''isurgent'')
                     THEN LTRIM(RTRIM(CONVERT(NVARCHAR(4000), p.[value]))) END) AS IsUrgentRaw,
            MAX(CASE WHEN nk.norm_key IN (N''urgent_remark'', N''urgent remark'', N''urgentremark'')
                     THEN LTRIM(RTRIM(CONVERT(NVARCHAR(4000), p.[value]))) END) AS UrgentRemarkRaw
        INTO #SMK069Urgent
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        CROSS APPLY OPENJSON(i.raw_json) AS p
        CROSS APPLY
        (
            SELECT LOWER(LTRIM(RTRIM(p.[key] COLLATE DATABASE_DEFAULT))) AS norm_key
        ) AS nk
        WHERE i.SiteRef = @Site
          AND i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
        GROUP BY i.inbound_id;

        UPDATE i
        SET
            is_urgent =
                CASE
                    WHEN TRY_CONVERT(DECIMAL(18,4), u.IsUrgentRaw) = 1 THEN 1
                    ELSE 0
                END,
            urgent_remark = LEFT(NULLIF(u.UrgentRemarkRaw, N''''), 255),
            updated_by = @ReceivedBy
        FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
        INNER JOIN #SMK069Urgent AS u
          ON u.inbound_id = i.inbound_id;

        /* =============================================================
           3. Snapshot BUSINESS SOURCE from mapping view';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'C1 persist urgent ke inbound', 1, 0, @Anchor, @Repl);

/* dbo.SMK069ReceivePosSalesJsonCoreSp :: C2 sync urgent ke temp */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'SET @TransferredRows = @@ROWCOUNT;';
SET @Repl = N'';
SET @Repl = @Repl + N'SET @TransferredRows = @@ROWCOUNT;

        /* =============================================================
           PATCH-36 Urgent flag - bawa is_urgent / urgent_remark dari
           inbound ke staging temp. Key join sama dengan verifikasi
           persistensi temp (SiteRef + co_num + co_line + cust_po).
           ============================================================= */
        UPDATE t
        SET
            is_urgent = i.is_urgent,
            urgent_remark = i.urgent_remark
        FROM dbo.ue_SMK069_temp_sales_mst AS t
        INNER JOIN #MapView AS v
          ON v.view_rn = 1
         AND v.view_row_count = 1
         AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), t.SiteRef))))
                 COLLATE DATABASE_DEFAULT
             = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(16), v.SiteRef))))
                 COLLATE DATABASE_DEFAULT
         AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(60), t.co_num))))
                 COLLATE DATABASE_DEFAULT
             = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(60), v.co_num))))
                 COLLATE DATABASE_DEFAULT
         AND t.co_line = v.co_line
         AND UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), t.cust_po))))
                 COLLATE DATABASE_DEFAULT
             = UPPER(LTRIM(RTRIM(CONVERT(NVARCHAR(100), v.cust_po))))
                 COLLATE DATABASE_DEFAULT
        INNER JOIN dbo.ue_SMK069_pos_sales_inbound_mst AS i
          ON i.inbound_id = v.inbound_id
        WHERE i.source_system = @SourceSystem
          AND i.batch_id = @BatchId
          AND i.inbound_status IN (N''V'', N''T'');';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'C2 sync urgent ke temp', 1, 0, @Anchor, @Repl);

/* dbo.SMK069ProcessCustomerOrderSp :: P1 repair kolom co_bln_mst */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'cost_conv,
                    allow_on_pick_list,
                    whse
                )';
SET @Repl = N'';
SET @Repl = @Repl + N'cost_conv,
                    Uf_SMK069_is_urgent,       /* PATCH-36 */
                    Uf_SMK069_urgent_remark,   /* PATCH-36 */
                    allow_on_pick_list,
                    whse
                )';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ProcessCustomerOrderSp', N'P1 repair kolom co_bln_mst', 1, 0, @Anchor, @Repl);

/* dbo.SMK069ProcessCustomerOrderSp :: P1 repair nilai co_bln_mst */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'ISNULL(i.unit_cost, 0),
                    0,
                    @Whse
                FROM dbo.ue_SMK069_temp_sales_mst AS s';
SET @Repl = N'';
SET @Repl = @Repl + N'ISNULL(i.unit_cost, 0),
                    ISNULL(s.is_urgent, 0),
                    s.urgent_remark,
                    0,
                    @Whse
                FROM dbo.ue_SMK069_temp_sales_mst AS s';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ProcessCustomerOrderSp', N'P1 repair nilai co_bln_mst', 1, 0, @Anchor, @Repl);

/* dbo.SMK069ProcessCustomerOrderSp :: P2 utama kolom co_bln_mst */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'cost_conv,
            allow_on_pick_list,
            whse
        )';
SET @Repl = N'';
SET @Repl = @Repl + N'cost_conv,
            Uf_SMK069_is_urgent,       /* PATCH-36 */
            Uf_SMK069_urgent_remark,   /* PATCH-36 */
            allow_on_pick_list,
            whse
        )';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ProcessCustomerOrderSp', N'P2 utama kolom co_bln_mst', 1, 0, @Anchor, @Repl);

/* dbo.SMK069ProcessCustomerOrderSp :: P2 utama nilai co_bln_mst */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'ISNULL(i.unit_cost, 0),
            0,
            @Whse
        FROM dbo.ue_SMK069_temp_sales_mst AS s';
SET @Repl = N'';
SET @Repl = @Repl + N'ISNULL(i.unit_cost, 0),
            ISNULL(s.is_urgent, 0),
            s.urgent_remark,
            0,
            @Whse
        FROM dbo.ue_SMK069_temp_sales_mst AS s';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ProcessCustomerOrderSp', N'P2 utama nilai co_bln_mst', 1, 0, @Anchor, @Repl);

/* dbo.SMK069ReceivePosSalesJsonCoreSp :: U1 komentar Is_Urgent */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'           Is_Urgent 1 / "1" / true -> 1, selain itu -> 0 (default Normal).';
SET @Repl = N'';
SET @Repl = @Repl + N'           Is_Urgent 1 / "1" -> 1, selain itu (termasuk true, "Y", 2) -> 0 (default Normal).';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'U1 komentar Is_Urgent', 1, 1, @Anchor, @Repl);

/* dbo.SMK069ReceivePosSalesJsonCoreSp :: U2 hapus true */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'                    WHEN LOWER(u.IsUrgentRaw) = N''true'' THEN 1
';
SET @Repl = N'';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'U2 hapus true', 1, 1, @Anchor, @Repl);

/* dbo.SMK069ReceivePosSalesJsonCoreSp :: U3 remark 255 */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'urgent_remark = LEFT(NULLIF(u.UrgentRemarkRaw, N''''), 250),';
SET @Repl = N'';
SET @Repl = @Repl + N'urgent_remark = LEFT(NULLIF(u.UrgentRemarkRaw, N''''), 255),';
INSERT INTO @Edit (obj_name, label, expected_count, is_upgrade, anchor, repl)
VALUES (N'dbo.SMK069ReceivePosSalesJsonCoreSp', N'U3 remark 255', 1, 1, @Anchor, @Repl);


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
    @Needs    BIT,
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
        SET @Msg = N'[PATCH-36] Definisi ' + @ObjName + N' tidak dapat dibaca (permission atau encrypted).';
        THROW 510367, @Msg, 1;
    END;

    /* Samakan akhir baris (CRLF/CR -> LF) supaya anchor tidak bergantung pada format file. */
    SET @Def = REPLACE(REPLACE(@Def, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

    SET @Needs = 0;

    IF CHARINDEX(N'PATCH-36', @Def COLLATE Latin1_General_100_BIN2) > 0
    BEGIN
        /* Sudah terpasang. Terapkan edit upgrade hanya bila teks versi lama masih ada. */
        SET @EditId = (SELECT MIN(edit_id) FROM @Edit WHERE obj_name = @ObjName AND is_upgrade = 1);

        WHILE @EditId IS NOT NULL
        BEGIN
            SELECT
                @Label  = e.label,
                @Anchor = e.anchor,
                @Repl   = e.repl
            FROM @Edit AS e
            WHERE e.edit_id = @EditId;

            SET @Anchor = REPLACE(REPLACE(@Anchor, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));
            SET @Repl   = REPLACE(REPLACE(@Repl,   NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

            SET @Found =
                (
                    DATALENGTH(@Def)
                    - DATALENGTH(REPLACE(@Def COLLATE Latin1_General_100_BIN2, @Anchor, N''))
                )
                / NULLIF(DATALENGTH(@Anchor), 0);

            IF ISNULL(@Found, 0) > 1
            BEGIN
                SET @Msg =
                    N'[PATCH-36] Edit upgrade "' + @Label + N'" pada ' + @ObjName
                    + N' ditemukan ' + CONVERT(NVARCHAR(20), @Found)
                    + N' kali (seharusnya 0 atau 1). Patch dibatalkan, procedure tidak diubah.';
                THROW 510374, @Msg, 1;
            END;

            IF ISNULL(@Found, 0) = 1
            BEGIN
                SET @Def = REPLACE(@Def COLLATE Latin1_General_100_BIN2, @Anchor, @Repl);
                SET @Needs = 1;
            END;

            SET @EditId =
                (
                    SELECT MIN(e.edit_id)
                    FROM @Edit AS e
                    WHERE e.obj_name = @ObjName
                      AND e.is_upgrade = 1
                      AND e.edit_id > @EditId
                );
        END;

        IF @Needs = 1
            PRINT N'[PATCH-36] UPGRADE blok versi pertama: ' + @ObjName;
        ELSE
            PRINT N'[PATCH-36] SKIP (sudah terpasang): ' + @ObjName;
    END
    ELSE
    BEGIN
        SET @Needs = 1;
        SET @EditId = (SELECT MIN(edit_id) FROM @Edit WHERE obj_name = @ObjName AND is_upgrade = 0);

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
                    N'[PATCH-36] Anchor "' + @Label + N'" pada ' + @ObjName
                    + N' ditemukan ' + CONVERT(NVARCHAR(20), ISNULL(@Found, -1))
                    + N' kali (seharusnya ' + CONVERT(NVARCHAR(20), @Expected)
                    + N'). Definisi di tenant berbeda dari repo. Patch dibatalkan, procedure tidak diubah. Lihat docs/csv-to-co/50-urgent-flag.md bagian pemasangan manual.';
                THROW 510368, @Msg, 1;
            END;

            SET @Def = REPLACE(@Def COLLATE Latin1_General_100_BIN2, @Anchor, @Repl);

            SET @EditId =
                (
                    SELECT MIN(e.edit_id)
                    FROM @Edit AS e
                    WHERE e.obj_name = @ObjName
                      AND e.is_upgrade = 0
                      AND e.edit_id > @EditId
                );
        END;
    END;

    IF @Needs = 1
    BEGIN
        /* Pastikan header bisa dieksekusi ulang: CREATE PROCEDURE -> ALTER PROCEDURE. */
        IF CHARINDEX(N'ALTER PROCEDURE', @Def COLLATE Latin1_General_100_CI_AS) = 0
        BEGIN
            SET @Pos = CHARINDEX(N'CREATE PROCEDURE', @Def COLLATE Latin1_General_100_CI_AS);

            IF @Pos = 0
            BEGIN
                SET @Msg = N'[PATCH-36] Header CREATE/ALTER PROCEDURE tidak ditemukan pada definisi ' + @ObjName + N'.';
                THROW 510369, @Msg, 1;
            END;

            SET @Def = STUFF(@Def, @Pos, LEN(N'CREATE PROCEDURE'), N'ALTER PROCEDURE');
        END;

        INSERT INTO @Plan (obj_name, new_def, skip_it)
        VALUES (@ObjName, @Def, 0);
    END
    ELSE
    BEGIN
        INSERT INTO @Plan (obj_name, new_def, skip_it)
        VALUES (@ObjName, N'', 1);
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
    PRINT N'[PATCH-36] OK diperbarui: ' + @ObjName;

    FETCH NEXT FROM PlanCursor INTO @ObjName, @Def;
END;

CLOSE PlanCursor;
DEALLOCATE PlanCursor;

COMMIT TRANSACTION;

/* =============================================================================
   5. POST-CHECK
   ============================================================================= */
DECLARE
    @CoreDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonCoreSp')), N''),
    @ProcDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N'');

IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'is_urgent') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'urgent_remark') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'is_urgent') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_temp_sales_mst', N'urgent_remark') IS NULL
    THROW 510370, N'[PATCH-36] Kolom is_urgent/urgent_remark belum lengkap di inbound/temp.', 1;

IF CHARINDEX(N'INTO #SMK069Urgent', @CoreDef) = 0
    THROW 510371, N'[PATCH-36] Blok baca Is_Urgent/Urgent Remark belum terpasang di Core.', 1;

IF CHARINDEX(N'PATCH-36 Urgent flag - bawa is_urgent', @CoreDef) = 0
    THROW 510372, N'[PATCH-36] Blok sync inbound -> temp belum terpasang di Core.', 1;

IF CHARINDEX(N'Uf_SMK069_is_urgent', @ProcDef) = 0
   OR CHARINDEX(N'Uf_SMK069_urgent_remark', @ProcDef) = 0
    THROW 510373, N'[PATCH-36] Insert co_bln_mst belum membawa field urgent di SMK069ProcessCustomerOrderSp.', 1;

PRINT N'[PATCH-36] SUCCESS - Is_Urgent dan Urgent Remark mengalir dari payload sampai co_bln_mst.';
