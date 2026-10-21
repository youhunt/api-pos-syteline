/* =============================================================================
   SMK069 - Patch 40 - Pesan API ramah untuk kuantitas tidak sesuai kelipatan U/M (POS-108)
   -----------------------------------------------------------------------------
   Date    : 2026-10-21
   Scope   : POS / CSV inbound -> Blanket Customer Order (respons API saja)
   Depends : Patch 28 (ValidationStatus), Patch 33/34 (POS-204) sudah terpasang
   Objects : dbo.SMK069ReceivePosSalesJsonSp   (diedit in-place)

   KEBUTUHAN
   ---------
   Di TRN, kuantitas yang tidak sesuai kelipatan U/M dikembalikan sebagai
   [POS-108] "Quantity tidak sesuai kelipatan U/M ... Material Code ...".
   Di PRD (paket 24 September) kasus yang sama keluar sebagai [POS-109]
   "Item/CustPO tidak valid berdasarkan ValidationStatus mapping" untuk SEMUA
   baris order. Patch ini menyamakan PRD dengan TRN.

   ISI PERUBAHAN
   -------------
   Satu blok baru "PATCH: Friendly POS-109 API message" disisipkan di
   SMK069ReceivePosSalesJsonSp, tepat sebelum komentar "PATCH-34: synthesize
   POS-204". Teks blok SAMA PERSIS dengan yang sudah berjalan di TRN.
     - Hanya baris yang benar-benar ValidationStatus = N yang dilaporkan.
     - Bila semua penyebabnya kuantitas pecahan -> kode POS-108, pesan memuat
       qty_ordered, u_m, qty_hasil_konversi, u_m_hasil. Bila ada penyebab lain
       -> tetap POS-109 dengan pesan "Item tidak valid atau tidak sesuai mapping".
     - validation_msg yang tersimpan (History) ikut dirapikan: baris akar
       POS-108, baris saudara POS-203.
   TIDAK berubah: validasi, status inbound, view mapping, signature procedure,
   metadata IDO, Core, ProcessBatch, ProcessCustomerOrder.

   MENGAPA DIEDIT IN-PLACE
   -----------------------
   Sama dengan Patch 36-38: definisi aktif dibaca dari OBJECT_DEFINITION, blok
   disisipkan pada anchor yang harus ada TEPAT sekali, lalu procedure di-ALTER.
     - Anchor tidak cocok -> patch BERHENTI (THROW), procedure tidak diubah.
     - Re-runnable: definisi yang sudah memuat teks blok dilewati (SKIP). Di TRN
       patch ini juga SKIP karena blok itu sudah ada.
     - Perbaikan manual yang sudah ada di PRD tidak tertimpa.
     - Perubahan dibungkus satu transaksi.

   CATATAN
   -------
     - Sebelum menjalankan di PRD, script-out SMK069ReceivePosSalesJsonSp sebagai
       cadangan rollback.
     - Tidak perlu Transactional=False diubah: method IDO tetap NOT Transactional.

   Apply Database compatible: one executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* =============================================================================
   0. PRECHECK
   ============================================================================= */
IF OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp', N'P') IS NULL
    THROW 510440, N'[PATCH-40] Procedure SMK069ReceivePosSalesJsonSp tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'U') IS NULL
    THROW 510441, N'[PATCH-40] Tabel ue_SMK069_pos_sales_inbound_mst tidak ditemukan.', 1;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'V') IS NULL
    THROW 510442, N'[PATCH-40] View ue_SMK069_pos_sales_inbound_mapping_view tidak ditemukan.', 1;

/* Kolom view yang dibaca blok baru. */
IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'inbound_id') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'qty_ordered') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'u_m') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mapping_view', N'ValidationStatus') IS NULL
    THROW 510443, N'[PATCH-40] View mapping tidak punya kolom inbound_id / qty_ordered / u_m / ValidationStatus.', 1;

/* Kolom inbound yang dibaca/ditulis blok baru. */
IF COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'inbound_id') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'row_no') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'co_line') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'qty_ordered') IS NULL
   OR COL_LENGTH(N'dbo.ue_SMK069_pos_sales_inbound_mst', N'validation_msg') IS NULL
    THROW 510444, N'[PATCH-40] Tabel inbound tidak punya kolom inbound_id / row_no / co_line / qty_ordered / validation_msg.', 1;

/* =============================================================================
   1. DAFTAR EDIT (anchor -> pengganti)
      Teks pengganti diambil dari definisi TRN yang sedang berjalan dan sama dengan
      isi file canonical di repo (database/procedures/csv-to-co/SMK069ReceivePosSalesJsonSp.sql).
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
    @Anchor     NVARCHAR(MAX),
    @Repl       NVARCHAR(MAX),
    @SkipMarker NVARCHAR(100) = N'Friendly POS-109 API message';

/* dbo.SMK069ReceivePosSalesJsonSp :: P1 blok friendly POS-108 (sebelum PATCH-34) */
SET @Anchor = N'';
SET @Anchor = @Anchor + N'/* PATCH-34: synthesize POS-204 from payload CustPO';
SET @Repl = N'';
SET @Repl = @Repl + N'/* =========================================================================
        PATCH: Friendly POS-109 API message

        Validation logic TIDAK diubah.
        Hanya memperbaiki response API:
        - Ambil hanya line yang benar-benar ValidationStatus = N
        - Jika penyebabnya qty hasil mapping pecahan, tampilkan sebagai POS-108
        - Jangan tampilkan istilah teknis "ValidationStatus mapping" ke caller
        ========================================================================= */
        IF @ErrorCode = N''POS-109''
        BEGIN
            DECLARE @Pos109Invalid TABLE
            (
                inbound_id      BIGINT         NOT NULL PRIMARY KEY,
                row_no          INT            NULL,
                cust_po         NVARCHAR(100)  NULL,
                co_line         INT            NULL,
                raw_item        NVARCHAR(100)  NULL,
                raw_qty         DECIMAL(23,8)  NULL,
                raw_um          NVARCHAR(80)   NULL,
                mapped_qty      DECIMAL(23,5)  NULL,
                mapped_um       NVARCHAR(80)   NULL,
                is_qty_multiple BIT            NOT NULL
            );

            INSERT INTO @Pos109Invalid
            (
                inbound_id,
                row_no,
                cust_po,
                co_line,
                raw_item,
                raw_qty,
                raw_um,
                mapped_qty,
                mapped_um,
                is_qty_multiple
            )
            SELECT
                e.inbound_id,
                e.row_no,
                LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.cust_po))),
                e.co_line,
                LTRIM(RTRIM(CONVERT(NVARCHAR(100), e.item))),
                CONVERT(DECIMAL(23,8), e.qty_ordered),
                LTRIM(RTRIM(CONVERT(NVARCHAR(80), e.u_m))),
                mv.mapped_qty,
                mv.mapped_um,

                CASE
                    WHEN mv.mapped_qty IS NOT NULL
                    AND mv.mapped_qty <> FLOOR(mv.mapped_qty)
                    THEN 1
                    ELSE 0
                END
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS e
            CROSS APPLY
            (
                SELECT TOP (1)
                    CONVERT(DECIMAL(23,5), v.qty_ordered) AS mapped_qty,
                    LTRIM(RTRIM(CONVERT(NVARCHAR(80), v.u_m))) AS mapped_um
                FROM dbo.ue_SMK069_pos_sales_inbound_mapping_view AS v
                WHERE v.inbound_id      = e.inbound_id
                AND v.SiteRef         = @Site
                AND v.source_system   = @SourceSystem
                AND v.batch_id        = @BatchId
                AND UPPER
                    (
                        LTRIM
                        (
                            RTRIM
';
SET @Repl = @Repl + N'                            (
                                CONVERT(NVARCHAR(20), v.ValidationStatus)
                            )
                        )
                    ) = N''N''
            ) AS mv
            WHERE e.SiteRef        = @Site
            AND e.source_system  = @SourceSystem
            AND e.batch_id       = @BatchId
            AND e.inbound_status = N''E'';


            IF EXISTS (SELECT 1 FROM @Pos109Invalid)
            BEGIN
                /* Count hanya root line yang memang ValidationStatus=N.
                Sibling valid yang ikut E karena atomic CustPO tidak dihitung. */
                SELECT @ErrorRowCount = COUNT(*)
                FROM @Pos109Invalid;


                /* Jika SEMUA N ternyata karena qty kelipatan,
                expose sebagai POS-108 ke API.

                Kalau ada penyebab N lainnya, tetap POS-109. */
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM @Pos109Invalid
                    WHERE is_qty_multiple = 0
                )
                BEGIN
                    SET @ErrorCode = N''POS-108'';
                END
                ELSE
                BEGIN
                    SET @ErrorCode = N''POS-109'';
                END;


                SELECT @ErrorList =
                    STUFF
                    (
                        (
                            SELECT
                                N'' | ''
                                + CASE
                                    WHEN NULLIF(p.cust_po, N'''') IS NULL
                                    THEN N''''
                                    ELSE N''[cust_po='' + p.cust_po + N''] ''
                                END
                                +
                                CASE
                                    WHEN p.is_qty_multiple = 1
                                    THEN
                                        N''Quantity tidak sesuai kelipatan U/M''
                                        + N'' [coline=''
                                        + COALESCE
                                        (
                                            CONVERT(NVARCHAR(20), p.co_line),
                                            N''<kosong>''
                                        )
                                        + N'', item=''
                                        + COALESCE(NULLIF(p.raw_item, N''''), N''<kosong>'')
                                        + N'', qty_ordered=''
                                        + COALESCE
                                        (
                                            CONVERT(NVARCHAR(60), p.raw_qty),
                                            N''<kosong>''
                                        )
                                        + N'', u_m=''
';
SET @Repl = @Repl + N'                                        + COALESCE(NULLIF(p.raw_um, N''''), N''<kosong>'')
                                        + N'', qty_hasil_konversi=''
                                        + COALESCE
                                        (
                                            CONVERT(NVARCHAR(60), p.mapped_qty),
                                            N''<kosong>''
                                        )
                                        + N'', u_m_hasil=''
                                        + COALESCE(NULLIF(p.mapped_um, N''''), N''<kosong>'')
                                        + N'']''

                                    ELSE
                                        N''Item tidak valid atau tidak sesuai mapping Infor''
                                        + N'' [coline=''
                                        + COALESCE
                                        (
                                            CONVERT(NVARCHAR(20), p.co_line),
                                  N''<kosong>''
                                        )
                                        + N'', item=''
                                        + COALESCE(NULLIF(p.raw_item, N''''), N''<kosong>'')
                                        + N'']''
                                END

                            FROM @Pos109Invalid AS p
                            ORDER BY p.row_no

                            FOR XML PATH(N''''), TYPE
                        ).value(N''.'', N''NVARCHAR(MAX)''),
                        1,
                        3,
                        N''''
                    );
            END;
        END;

        /* =============================================================
        Keep persisted validation_msg consistent with friendly API error.

        IMPORTANT:
        - Tidak mengubah status
        - Tidak mengubah validasi
        - Tidak mengubah mapping
        - Hanya memperbaiki pesan yang disimpan untuk History
        ============================================================= */
        IF EXISTS (SELECT 1 FROM @Pos109Invalid)
        AND NOT EXISTS
        (
            SELECT 1
            FROM @Pos109Invalid
            WHERE is_qty_multiple = 0
        )
        BEGIN
            /* Root line:
            benar-benar gagal karena quantity tidak sesuai kelipatan */
            UPDATE i
            SET i.validation_msg =
                LEFT
                (
                    N''[POS-108] Quantity tidak sesuai kelipatan U/M.''
                    + N'' qty_ordered=''
                    + COALESCE(CONVERT(NVARCHAR(60), p.raw_qty), N''<kosong>'')
                    + N''; u_m=''
                    + COALESCE(NULLIF(p.raw_um, N''''), N''<kosong>'')
                    + N''; qty_hasil_konversi=''
                    + COALESCE(CONVERT(NVARCHAR(60), p.mapped_qty), N''<kosong>'')
';
SET @Repl = @Repl + N'                    + N''; u_m_hasil=''
                    + COALESCE(NULLIF(p.mapped_um, N''''), N''<kosong>''),
                    2000
                )
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            INNER JOIN @Pos109Invalid AS p
                ON p.inbound_id = i.inbound_id
            WHERE i.SiteRef       = @Site
            AND i.source_system = @SourceSystem
            AND i.batch_id      = @BatchId
            AND i.inbound_status = N''E''
            AND p.is_qty_multiple = 1;


            /* Sibling line:
            line sebenarnya valid, tetapi CustPO ikut ditolak karena
            ada line lain yang invalid */
            UPDATE i
            SET i.validation_msg =
                N''[POS-203] Order ditolak karena terdapat line lain yang tidak valid.''
            FROM dbo.ue_SMK069_pos_sales_inbound_mst AS i
            WHERE i.SiteRef        = @Site
            AND i.source_system  = @SourceSystem
            AND i.batch_id       = @BatchId
            AND i.inbound_status = N''E''

            /* hanya row yang sebelumnya terkena POS-109 */
            AND i.validation_msg LIKE N''%ValidationStatus=N%''

            /* CustPO memang punya root error quantity */
            AND EXISTS
            (
                SELECT 1
                FROM @Pos109Invalid AS p
                WHERE p.cust_po =
                        LTRIM(RTRIM(CONVERT(NVARCHAR(100), i.cust_po)))
                    AND p.is_qty_multiple = 1
            )

            /* tetapi row ini sendiri bukan root error */
            AND NOT EXISTS
            (
                SELECT 1
                FROM @Pos109Invalid AS p
                WHERE p.inbound_id = i.inbound_id
            );
        END;

        /* PATCH-34: synthesize POS-204 from payload CustPO';
INSERT INTO @Edit (obj_name, label, expected_count, anchor, repl)
VALUES (N'dbo.SMK069ReceivePosSalesJsonSp', N'P1 blok friendly POS-108', 1, @Anchor, @Repl);

/* =============================================================================
   2. FASE A - SUSUN DEFINISI BARU (belum mengubah object apa pun)
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
        SET @Msg = N'[PATCH-40] Definisi ' + @ObjName + N' tidak dapat dibaca (permission atau encrypted).';
        THROW 510445, @Msg, 1;
    END;

    /* Samakan akhir baris (CRLF/CR -> LF) supaya anchor tidak bergantung pada format file. */
    SET @Def = REPLACE(REPLACE(@Def, NCHAR(13) + NCHAR(10), NCHAR(10)), NCHAR(13), NCHAR(10));

    IF CHARINDEX(@SkipMarker, @Def COLLATE Latin1_General_100_BIN2) > 0
    BEGIN
        PRINT N'[PATCH-40] SKIP (sudah terpasang): ' + @ObjName;

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
                    N'[PATCH-40] Anchor "' + @Label + N'" pada ' + @ObjName
                    + N' ditemukan ' + CONVERT(NVARCHAR(20), ISNULL(@Found, -1))
                    + N' kali (seharusnya ' + CONVERT(NVARCHAR(20), @Expected)
                    + N'). Definisi di tenant berbeda dari repo (Patch 33/34 belum terpasang atau teksnya berbeda). Patch dibatalkan, procedure tidak diubah. Script-out definisi tenant dan bandingkan dengan file canonical di repo.';
                THROW 510446, @Msg, 1;
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
                N'[PATCH-40] Header CREATE/ALTER PROC[EDURE] tidak dikenali pada ' + @ObjName
                + N'. Awal definisi: '
                + LEFT(REPLACE(REPLACE(REPLACE(@Def, NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' '), 160);
            THROW 510447, @Msg, 1;
        END;

        INSERT INTO @Plan (obj_name, new_def, skip_it)
        VALUES (@ObjName, @Def, 0);
    END;

    FETCH NEXT FROM ObjCursor INTO @ObjName;
END;

CLOSE ObjCursor;
DEALLOCATE ObjCursor;

/* =============================================================================
   3. FASE B - TERAPKAN (satu transaksi; XACT_ABORT ON => rollback otomatis)
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
    PRINT N'[PATCH-40] OK diperbarui: ' + @ObjName;

    FETCH NEXT FROM PlanCursor INTO @ObjName, @Def;
END;

CLOSE PlanCursor;
DEALLOCATE PlanCursor;

COMMIT TRANSACTION;

/* =============================================================================
   4. POST-CHECK
   ============================================================================= */
DECLARE @ProcDef NVARCHAR(MAX) = COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SMK069ReceivePosSalesJsonSp')), N'');

IF CHARINDEX(@SkipMarker, @ProcDef) = 0
    THROW 510448, N'[PATCH-40] Blok "Friendly POS-109 API message" tidak ditemukan di SMK069ReceivePosSalesJsonSp setelah patch.', 1;

IF CHARINDEX(N'qty_hasil_konversi', @ProcDef) = 0
    THROW 510449, N'[PATCH-40] Teks POS-108 ramah (qty_hasil_konversi) tidak ditemukan di SMK069ReceivePosSalesJsonSp setelah patch.', 1;

IF CHARINDEX(N'@ThrowOnBusinessError', @ProcDef) = 0
    THROW 510450, N'[PATCH-40] Signature SMK069ReceivePosSalesJsonSp berubah tidak terduga (parameter @ThrowOnBusinessError hilang).', 1;

PRINT N'[PATCH-40] SUCCESS - kuantitas tidak sesuai kelipatan U/M kini dilaporkan sebagai POS-108 (sama dengan TRN).';
