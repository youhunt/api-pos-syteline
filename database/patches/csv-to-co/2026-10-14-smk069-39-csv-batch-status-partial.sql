/* =============================================================================
   SMK069 - Patch 39 - CHECK constraint batch_status harus mengizinkan 'P' (partial)
   -----------------------------------------------------------------------------
   Date    : 2026-10-14
   Scope   : CSV -> Blanket Customer Order (tabel header batch)
   Depends : tidak ada (tidak bergantung pada Patch 36-38)
   Objects : dbo.ue_SMK069_pos_csv_batch_mst  (constraint CK_SMK069CsvBatch_Status)

   GEJALA
   ------
   Form "SMK POS CSV TO BLANKET CO" menampilkan:
     [POS-999] CSV -> SMK069ReceivePosSalesJsonSp gagal 547: The UPDATE statement
     conflicted with the CHECK constraint "CK_SMK069CsvBatch_Status" ...
   padahal order yang valid SUDAH menjadi Customer Order (temp.process_status = 'P',
   created_co_num terisi). Batch lalu tampil 'E' (gagal) walau sebagian berhasil.

   PENYEBAB
   --------
   SMK069RunCsvTestBatchSp menutup batch dengan batch_status:
       C = semua order jadi Customer Order
       P = partial (sebagian order ditolak, sisanya jadi CO; mis. POS-204 cust_po
           sudah terdaftar)                                  <- ditambahkan Patch 03
       E = tidak ada yang masuk
       R = running,  D = draft
   Constraint di DB ini hanya mengizinkan D, R, C, E. Setiap batch partial
   (misalnya satu cust_po duplikat + satu cust_po baru dalam satu file) membuat
   UPDATE terakhir ditolak (547), lalu blok CATCH menimpa status menjadi 'E' dan
   result_message menjadi pesan POS-999.

   Definisi constraint tidak ada di repo (dibuat di luar patch, kemungkinan lewat
   Mongoose/DDL manual), jadi Patch 03 tidak memperluasnya. Patch ini memperbaikinya.

   YANG DILAKUKAN
   --------------
   - Constraint tidak ada      -> tidak berbuat apa-apa (semua nilai sudah boleh).
   - Constraint sudah memuat P -> tidak berbuat apa-apa.
   - Lainnya                   -> DROP lalu ADD constraint dengan nama yang sama:
                                  batch_status IN (D, R, C, P, E).
   Satu transaksi; bila ADD gagal (mis. ada baris dengan status di luar daftar),
   DROP ikut dibatalkan dan constraint lama tetap utuh.

   DAMPAK PADA DATA
   ----------------
   Tidak ada baris yang diubah. Batch yang sudah terlanjur tampil 'E' karena error
   ini tidak diperbaiki otomatis; jalankan Retry / Process CO pada batch yang sama
   (idempotent) untuk menghitung ulang status dan result_message.

   CARA JALAN: Apply Database, satu batch, TANPA GO. Aman dijalankan ulang.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst', N'U') IS NULL
    THROW 510420, N'[PATCH-39] Tabel dbo.ue_SMK069_pos_csv_batch_mst tidak ditemukan.', 1;

DECLARE @Def NVARCHAR(MAX) =
(
    SELECT cc.definition
    FROM sys.check_constraints AS cc
    WHERE cc.name = N'CK_SMK069CsvBatch_Status'
      AND cc.parent_object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst')
);

IF @Def IS NULL
BEGIN
    PRINT N'[PATCH-39] Constraint CK_SMK069CsvBatch_Status tidak ada; tidak ada yang perlu diubah.';
END
ELSE IF CHARINDEX(N'N''P''', @Def) > 0
BEGIN
    PRINT N'[PATCH-39] Constraint sudah mengizinkan P; dilewati. Definisi: ' + @Def;
END
ELSE
BEGIN
    PRINT N'[PATCH-39] Definisi lama: ' + @Def;

    BEGIN TRY
        BEGIN TRANSACTION;

        ALTER TABLE dbo.ue_SMK069_pos_csv_batch_mst
            DROP CONSTRAINT CK_SMK069CsvBatch_Status;

        ALTER TABLE dbo.ue_SMK069_pos_csv_batch_mst WITH CHECK
            ADD CONSTRAINT CK_SMK069CsvBatch_Status
            CHECK (batch_status IN (N'D', N'R', N'C', N'P', N'E'));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @Msg NVARCHAR(2000) =
            N'[PATCH-39] Gagal memperluas constraint, constraint lama tetap utuh: '
            + CONVERT(NVARCHAR(20), ERROR_NUMBER()) + N' - ' + ERROR_MESSAGE();
        THROW 510421, @Msg, 1;
    END CATCH;
END;

/* POST-CHECK: constraint (bila ada) harus memuat P. */
DECLARE @After NVARCHAR(MAX);
SELECT @After = cc.definition
FROM sys.check_constraints AS cc
WHERE cc.name = N'CK_SMK069CsvBatch_Status'
  AND cc.parent_object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_csv_batch_mst');

IF @After IS NOT NULL AND CHARINDEX(N'N''P''', @After) = 0
    THROW 510422, N'[PATCH-39] Constraint CK_SMK069CsvBatch_Status masih belum mengizinkan P setelah patch.', 1;

PRINT N'[PATCH-39] SUCCESS - batch_status mengizinkan D, R, C, P, E. Definisi sekarang: '
    + COALESCE(@After, N'(constraint tidak ada)');
