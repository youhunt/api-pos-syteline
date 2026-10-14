/* =============================================================================
   SMK069 - Patch 38 - Urgent flag juga disimpan di Customer Order line (coitem_mst)
   -----------------------------------------------------------------------------
   Date    : 2026-10-14
   Scope   : CSV / POS inbound -> Blanket Customer Order ONLY
   Depends : Patch 36 (Process sudah mengisi co_bln_mst)
   Objects : dbo.SMK069ProcessCustomerOrderSp   (diedit in-place)
             dbo.coitem_mst                     (UET Uf_SMK069_is_urgent / Uf_SMK069_urgent_remark, dibuat lewat Mongoose)

   KEBUTUHAN
   ---------
   Form "Customer Order Blanket Releases" memakai primary collection SL.SLCoitems
   (tabel coitem_mst), bukan SLCoBlns. Nilai urgent dari Patch 36 hanya ada di
   co_bln_mst, sehingga form itu tidak bisa menampilkannya. Patch ini membuat
   SMK069ProcessCustomerOrderSp mengisi dua field yang sama juga di coitem_mst:

     staging temp (is_urgent / urgent_remark)
        -> co_bln_mst.Uf_SMK069_is_urgent / Uf_SMK069_urgent_remark   (Patch 36)
        -> coitem_mst.Uf_SMK069_is_urgent / Uf_SMK069_urgent_remark   (Patch 38)

   Aturan nilai sama dengan Patch 36 (1 = urgent, selain 1 = 0, remark opsional
   maks 255). Nilai sudah dinormalkan sebelum masuk staging, jadi Process hanya
   menyalin: ISNULL(s.is_urgent, 0) dan s.urgent_remark.

   PRASYARAT (di luar patch ini, Mongoose)
   ---------------------------------------
   UET pada coitem_mst harus sudah dibuat dan Impact Schema sudah dijalankan:
     Uf_SMK069_is_urgent       int
     Uf_SMK069_urgent_remark   nvarchar(255)
   Lihat docs/csv-to-co/50-urgent-flag.md bagian "Form Customer Order Blanket
   Releases". Tanpa kolom itu, patch berhenti di precheck sebelum mengubah apa pun.

   BACKFILL
   --------
   Setelah procedure diperbarui, patch menyalin nilai urgent dari co_bln_mst ke
   coitem_mst untuk CO yang SUDAH ada (misalnya hasil UAT Patch 36) agar tampil di
   form Releases. Hanya baris yang urgent atau punya remark, dan hanya bila nilainya
   berbeda; aman dijalankan ulang.

   MENGAPA DIEDIT IN-PLACE
   -----------------------
   Sama dengan Patch 36/37: definisi aktif dibaca dari OBJECT_DEFINITION, edit
   disisipkan pada anchor yang harus ada TEPAT sekali, lalu CREATE OR ALTER ulang.
     - Anchor tidak cocok -> patch BERHENTI (THROW), procedure tidak diubah.
     - Re-runnable: object yang sudah memuat marker PATCH-38 dilewati.
     - Perubahan procedure dibungkus satu transaksi.
     - Signature procedure tidak berubah, metadata IDO method tidak berubah.

   CATATAN
   -------
     - Sebelum menjalankan, script-out SMK069ProcessCustomerOrderSp dari tenant
       sebagai cadangan rollback.
     - Impact Schema pada coitem_mst menambah kolom ke tabel yang besar; jalankan di
       luar jam sibuk pada PRD.

   Apply Database compatible: one executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* =============================================================================
   0. PRECHECK
   ============================================================================= */
IF OBJECT_ID(N'dbo.coitem_mst', N'U') IS NULL
    THROW 510400, N'[PATCH-38] Tabel coitem_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.co_bln_mst', N'U') IS NULL
    THROW 510401, N'[PATCH-38] Tabel co_bln_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp', N'P') IS NULL
    THROW 510402, N'[PATCH-38] Procedure SMK069ProcessCustomerOrderSp tidak ditemukan.', 1;

IF COL_LENGTH(N'dbo.co_bln_mst', N'Uf_SMK069_is_urgent') IS NULL
   OR COL_LENGTH(N'dbo.co_bln_mst', N'Uf_SMK069_urgent_remark') IS NULL
    THROW 510403, N'[PATCH-38] UET co_bln_mst belum ada. Jalankan Patch 36 beserta UET-nya dulu.', 1;

IF COL_LENGTH(N'dbo.coitem_mst', N'Uf_SMK069_is_urgent') IS NULL
   OR COL_LENGTH(N'dbo.coitem_mst', N'Uf_SMK069_urgent_remark') IS NULL
    THROW 510404, N'[PATCH-38] UET coitem_mst belum ada (Uf_SMK069_is_urgent dan/atau Uf_SMK069_urgent_remark). Buat UET + jalankan Impact Schema dulu, lihat docs/csv-to-co/50-urgent-flag.md bagian Form Customer Order Blanket Releases, lalu jalankan ulang patch ini.', 1;

DECLARE @CoitemRemarkBytes INT = COL_LENGTH(N'dbo.coitem_mst', N'Uf_SMK069_urgent_remark');

/* COL_LENGTH = byte; nvarchar(255) = 510 byte; nvarchar(max) = -1. */
IF @CoitemRemarkBytes <> -1 AND @CoitemRemarkBytes < 510
    THROW 510405, N'[PATCH-38] coitem_mst.Uf_SMK069_urgent_remark harus nvarchar(255) atau lebih besar agar remark tidak terpotong.', 1;

/* Tanpa Patch 36, Process belum membawa urgent dari staging; Patch 38 menumpang pada pola itu. */
IF CHARINDEX
   (
       N'PATCH-36',
       COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N'')
   ) = 0
    THROW 510406, N'[PATCH-38] Patch 36 belum terpasang di SMK069ProcessCustomerOrderSp. Jalankan Patch 36 dulu, lalu jalankan ulang patch ini.', 1;

/* =============================================================================
   1. DAFTAR EDIT (anchor -> pengganti)
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

/* dbo.SMK069ProcessCustomerOrderSp :: P3 kolom coitem_mst */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'stat,
            consolidate
        )';
SET @Repl = N'';
SET @Repl = @Repl + N'stat,
            consolidate,
            Uf_SMK069_is_urgent,       /* PATCH-38 */
            Uf_SMK069_urgent_remark    /* PATCH-38 */
        )';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ProcessCustomerOrderSp', N'P3 kolom coitem_mst', 1, @Anchor, @Repl);

/* dbo.SMK069ProcessCustomerOrderSp :: P4 nilai coitem_mst */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'N''O'',
            1
        FROM dbo.ue_SMK069_temp_sales_mst AS s';
SET @Repl = N'';
SET @Repl = @Repl + N'N''O'',
            1,
            ISNULL(s.is_urgent, 0),
            s.urgent_remark
        FROM dbo.ue_SMK069_temp_sales_mst AS s';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ProcessCustomerOrderSp', N'P4 nilai coitem_mst', 1, @Anchor, @Repl);


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
        SET @Msg = N'[PATCH-38] Definisi ' + @ObjName + N' tidak dapat dibaca (permission atau encrypted).';
        THROW 510406, @Msg, 1;
    END;

    /* Samakan akhir baris (CRLF/CR -> LF) supaya anchor tidak bergantung pada format file. */
    SET @Def = REPLACE(REPLACE(@Def, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

    IF CHARINDEX(N'PATCH-38', @Def COLLATE Latin1_General_100_BIN2) > 0
    BEGIN
        PRINT N'[PATCH-38] SKIP (sudah terpasang): ' + @ObjName;

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
                    N'[PATCH-38] Anchor "' + @Label + N'" pada ' + @ObjName
                    + N' ditemukan ' + CONVERT(NVARCHAR(20), ISNULL(@Found, -1))
                    + N' kali (seharusnya ' + CONVERT(NVARCHAR(20), @Expected)
                    + N'). Definisi di tenant berbeda dari repo. Patch dibatalkan, procedure tidak diubah. Lihat docs/csv-to-co/50-urgent-flag.md bagian Form Releases.';
                THROW 510407, @Msg, 1;
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
                N'[PATCH-38] Header CREATE/ALTER PROC[EDURE] tidak dikenali pada ' + @ObjName
                + N'. Awal definisi: '
                + LEFT(REPLACE(REPLACE(REPLACE(@Def, NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' '), 160);
            THROW 510408, @Msg, 1;
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
    PRINT N'[PATCH-38] OK diperbarui: ' + @ObjName;

    FETCH NEXT FROM PlanCursor INTO @ObjName, @Def;
END;

CLOSE PlanCursor;
DEALLOCATE PlanCursor;

COMMIT TRANSACTION;


/* =============================================================================
   2. BACKFILL CO yang sudah ada (co_bln_mst -> coitem_mst)
      Lewat sp_executesql agar batch ini tetap bisa dikompilasi walau kolom UET
      belum ada (precheck di atas sudah menghentikan patch pada kasus itu).
   ============================================================================= */
DECLARE @BackfillRows INT = 0;

EXEC sys.sp_executesql N'
UPDATE ci
SET
    ci.Uf_SMK069_is_urgent = b.Uf_SMK069_is_urgent,
    ci.Uf_SMK069_urgent_remark = b.Uf_SMK069_urgent_remark
FROM dbo.coitem_mst AS ci
INNER JOIN dbo.co_bln_mst AS b
  ON b.site_ref = ci.site_ref
 AND b.co_num = ci.co_num
 AND b.co_line = ci.co_line
WHERE
    (
        ISNULL(b.Uf_SMK069_is_urgent, 0) <> 0
        OR b.Uf_SMK069_urgent_remark IS NOT NULL
    )
    AND
    (
        ISNULL(ci.Uf_SMK069_is_urgent, 0) <> ISNULL(b.Uf_SMK069_is_urgent, 0)
        OR ISNULL(ci.Uf_SMK069_urgent_remark, N'''') <> ISNULL(b.Uf_SMK069_urgent_remark, N'''')
    );

SET @Rows = @@ROWCOUNT;',
    N'@Rows INT OUTPUT',
    @Rows = @BackfillRows OUTPUT;

PRINT N'[PATCH-38] Backfill coitem_mst dari co_bln_mst: ' + CONVERT(NVARCHAR(20), @BackfillRows) + N' baris.';

/* =============================================================================
   3. POST-CHECK
   ============================================================================= */
DECLARE @ProcDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ProcessCustomerOrderSp')), N'');

IF CHARINDEX(N'PATCH-38', @ProcDef) = 0
    THROW 510409, N'[PATCH-38] Marker PATCH-38 tidak ditemukan di SMK069ProcessCustomerOrderSp setelah patch.', 1;

/* Uf_SMK069_is_urgent harus muncul minimal 3 kali: 2 INSERT co_bln_mst (Patch 36) + INSERT coitem_mst (Patch 38). */
IF (LEN(@ProcDef) - LEN(REPLACE(@ProcDef, N'Uf_SMK069_is_urgent', N''))) / LEN(N'Uf_SMK069_is_urgent') < 3
    THROW 510410, N'[PATCH-38] INSERT coitem_mst belum membawa Uf_SMK069_is_urgent di SMK069ProcessCustomerOrderSp.', 1;

PRINT N'[PATCH-38] SUCCESS - urgent mengalir sampai coitem_mst (form Customer Order Blanket Releases).';
