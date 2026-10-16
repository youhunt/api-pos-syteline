/* =============================================================================
   SMK069 - Urgent flag (Patch 36-39) - PRECHECK / VERIFY  (READ-ONLY)
   -----------------------------------------------------------------------------
   Date    : 2026-10-16
   Dipakai : 1) di environment TUJUAN sebelum memasang patch  -> grup A, B, C harus OK
             2) sesudah semua patch dan form terpasang         -> grup A-D harus OK
   Aman    : hanya membaca katalog dan definisi objek; tidak mengubah apa pun.
   Cara    : jalankan satu batch tanpa GO (query tool / Apply Database).
             Hasil: satu tabel; baris terakhir = jumlah BELUM.

   Arti status
     OK     item sudah sesuai
     BELUM  item belum ada / belum sesuai (lihat kolom detail)

   Grup
     A  objek dasar fitur CSV/POS -> CO harus sudah ada di target
     B  UET Mongoose (co_bln_mst, coitem_mst) harus dibuat DULU, sebelum Patch 36/38
     C  kolom Peak Season (prasyarat anchor Patch 36)
     D  hasil patch: kolom baru, marker patch di procedure, constraint batch_status
   ============================================================================= */
SET NOCOUNT ON;

DECLARE @R TABLE
(
    step   INT IDENTITY(1,1) PRIMARY KEY,
    grp    NVARCHAR(30),
    item   NVARCHAR(90),
    status NVARCHAR(8),
    detail NVARCHAR(90)
);

/* ---- A. objek dasar ------------------------------------------------------ */
DECLARE @Obj TABLE (n SYSNAME, t VARCHAR(2));
INSERT @Obj (n, t) VALUES
    (N'ue_SMK069_pos_sales_inbound_mst',          'U'),
    (N'ue_SMK069_temp_sales_mst',                 'U'),
    (N'ue_SMK069_pos_csv_batch_mst',              'U'),
    (N'ue_SMK069_pos_csv_upload_mst',             'U'),
    (N'ue_SMK069_pos_sales_inbound_mapping_view', 'V'),
    (N'co_bln_mst',                               'U'),
    (N'coitem_mst',                               'U'),
    (N'SMK069ReceivePosSalesJsonSp',              'P'),
    (N'SMK069ReceivePosSalesJsonCoreSp',          'P'),
    (N'SMK069ProcessBatchCustomerOrdersSp',       'P'),
    (N'SMK069ProcessCustomerOrderSp',             'P'),
    (N'SMK069ImportCsvFileSp',                    'P'),
    (N'SMK069RunCsvTestBatchSp',                  'P');

INSERT @R (grp, item, status, detail)
SELECT N'A. Objek dasar',
       o.n,
       CASE WHEN OBJECT_ID(N'dbo.' + o.n, o.t) IS NULL THEN N'BELUM' ELSE N'OK' END,
       N'harus sudah ada di target'
FROM @Obj AS o;

/* ---- B / C / D. kolom ---------------------------------------------------- */
DECLARE @Col TABLE (grp NVARCHAR(30), t SYSNAME, c SYSNAME, minlen INT, note NVARCHAR(60));
INSERT @Col (grp, t, c, minlen, note) VALUES
    (N'B. UET (Mongoose)', N'co_bln_mst', N'Uf_SMK069_is_urgent',     4,   N'UET int + Impact Schema'),
    (N'B. UET (Mongoose)', N'co_bln_mst', N'Uf_SMK069_urgent_remark', 510, N'UET nvarchar(255) = 510 byte'),
    (N'B. UET (Mongoose)', N'coitem_mst', N'Uf_SMK069_is_urgent',     4,   N'UET int + Impact Schema'),
    (N'B. UET (Mongoose)', N'coitem_mst', N'Uf_SMK069_urgent_remark', 510, N'UET nvarchar(255) = 510 byte'),
    (N'C. Peak Season',    N'ue_SMK069_pos_sales_inbound_mst', N'is_peak_season', 1, N'prasyarat Patch 36'),
    (N'C. Peak Season',    N'ue_SMK069_temp_sales_mst',        N'is_peak_season', 1, N'prasyarat Patch 36'),
    (N'C. Peak Season',    N'ue_SMK069_pos_csv_upload_mst',    N'is_peak_season', 1, N'prasyarat Patch 37'),
    (N'D. Hasil patch',    N'ue_SMK069_pos_sales_inbound_mst', N'is_urgent',      4,   N'dibuat Patch 36'),
    (N'D. Hasil patch',    N'ue_SMK069_pos_sales_inbound_mst', N'urgent_remark',  510, N'dibuat Patch 36'),
    (N'D. Hasil patch',    N'ue_SMK069_temp_sales_mst',        N'is_urgent',      4,   N'dibuat Patch 36'),
    (N'D. Hasil patch',    N'ue_SMK069_temp_sales_mst',        N'urgent_remark',  510, N'dibuat Patch 36'),
    (N'D. Hasil patch',    N'ue_SMK069_pos_csv_upload_mst',    N'is_urgent',      4,   N'dibuat Patch 37'),
    (N'D. Hasil patch',    N'ue_SMK069_pos_csv_upload_mst',    N'urgent_remark',  510, N'dibuat Patch 37');

INSERT @R (grp, item, status, detail)
SELECT k.grp,
       k.t + N'.' + k.c,
       CASE WHEN COL_LENGTH(N'dbo.' + k.t, k.c) >= k.minlen THEN N'OK' ELSE N'BELUM' END,
       CASE WHEN COL_LENGTH(N'dbo.' + k.t, k.c) IS NULL THEN N'kolom tidak ada - ' + k.note
            WHEN COL_LENGTH(N'dbo.' + k.t, k.c) < k.minlen THEN N'terlalu pendek (' + CONVERT(NVARCHAR(10), COL_LENGTH(N'dbo.' + k.t, k.c)) + N' byte) - ' + k.note
            ELSE k.note END
FROM @Col AS k;

/* ---- D. marker patch pada procedure -------------------------------------- */
DECLARE @Mk TABLE (p SYSNAME, marker NVARCHAR(20), need NVARCHAR(40));
INSERT @Mk (p, marker, need) VALUES
    (N'SMK069ReceivePosSalesJsonCoreSp', N'PATCH-36', N'Patch 36'),
    (N'SMK069ProcessCustomerOrderSp',    N'PATCH-36', N'Patch 36'),
    (N'SMK069ImportCsvFileSp',           N'PATCH-37', N'Patch 37'),
    (N'SMK069RunCsvTestBatchSp',         N'PATCH-37', N'Patch 37'),
    (N'SMK069ProcessCustomerOrderSp',    N'PATCH-38', N'Patch 38');

INSERT @R (grp, item, status, detail)
SELECT N'D. Hasil patch',
       m.p + N' ' + m.marker,
       CASE WHEN CHARINDEX(m.marker, COALESCE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + m.p)), N'')) > 0 THEN N'OK' ELSE N'BELUM' END,
       m.need
FROM @Mk AS m;

/* ---- D. constraint batch_status (Patch 39) ------------------------------- */
DECLARE @Ck NVARCHAR(MAX) =
(
    SELECT cc.definition
    FROM sys.check_constraints AS cc
    WHERE cc.name = N'CK_SMK069CsvBatch_Status'
      AND cc.parent_object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst')
);

INSERT @R (grp, item, status, detail)
SELECT N'D. Hasil patch',
       N'CK_SMK069CsvBatch_Status mengizinkan P',
       CASE WHEN @Ck IS NULL OR CHARINDEX(N'N''P''', @Ck) > 0 THEN N'OK' ELSE N'BELUM' END,
       CASE WHEN @Ck IS NULL THEN N'constraint tidak ada (semua status boleh)'
            WHEN CHARINDEX(N'N''P''', @Ck) > 0 THEN N'sudah memuat P'
            ELSE N'Patch 39 diperlukan' END;

/* ---- ringkasan ------------------------------------------------------------ */
INSERT @R (grp, item, status, detail)
SELECT N'Z. Ringkasan',
       N'Jumlah item BELUM',
       CONVERT(NVARCHAR(8), COUNT(*)),
       N'sebelum patch: A-C harus 0; sesudah: semua 0'
FROM @R
WHERE status = N'BELUM';

SELECT grp, item, status, detail
FROM @R
ORDER BY step;
