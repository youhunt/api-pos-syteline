/* =============================================================================
   SMK069 - Salin field-map POS ke site lain (mis. TRN_TBB)
   -----------------------------------------------------------------------------
   Date    : 2026-10-28
   Object  : dbo.ue_SMK069_pos_field_map_mst (data + kunci tabel)

   GEJALA
   ------
   CSV/POS ditolak [POS-101] "Data payload tidak terdaftar atau tidak sesuai di
   Infor [coline=<kosong>, custnum=<kosong>, item=<kosong>, u_m=<kosong>,
   whse=<kosong>]" dan cust_po juga kosong.

   PENYEBAB
   --------
   SMK069ReceivePosSalesJsonCoreSp memetakan key payload lewat field-map dengan
   filter SiteRef = site aktif. Field-map hanya berisi baris untuk site 'Default';
   pengguna login di site 'TRN_TBB', sehingga tidak ada baris yang cocok dan SEMUA
   kolom inbound menjadi NULL.

   KENDALA
   -------
   Kunci utama tabel hanya (source_system, source_field), tanpa SiteRef, jadi dua
   site tidak bisa memakai source_system 'POS' yang sama. Script ini:
     1. mengubah kunci utama menjadi (SiteRef, source_system, source_field)
        (hanya bila SiteRef belum ada di kunci; tabel kecil, ~36 baris);
     2. menyalin semua baris @FromSite ke @NewSite dengan RowPointer baru.
   Baris site asal TIDAK diubah, jadi site 'Default' tetap berfungsi.
   Aman dijalankan ulang: baris yang sudah ada di @NewSite dilewati.

   PAKAI
   -----
   Ubah dua nilai di bawah sesuai environment (nilai site = SiteRef persis seperti
   di kolom SiteRef inbound hasil query pengecekan). Jalankan sebagai satu batch,
   TANPA GO. Semua perubahan satu transaksi; error apa pun = rollback otomatis.

   ROLLBACK
   --------
   DELETE FROM dbo.ue_SMK069_pos_field_map_mst WHERE SiteRef = <@NewSite>;
   (kunci utama yang sudah memuat SiteRef boleh dibiarkan.)
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FromSite NVARCHAR(8) = N'Default';
DECLARE @NewSite  NVARCHAR(8) = N'TRN_TBB';

IF OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst', N'U') IS NULL
    THROW 510460, N'[FIELDMAP] Tabel ue_SMK069_pos_field_map_mst tidak ditemukan.', 1;

IF @FromSite = @NewSite
    THROW 510461, N'[FIELDMAP] @FromSite dan @NewSite tidak boleh sama.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ue_SMK069_pos_field_map_mst
    WHERE SiteRef = @FromSite
      AND is_active = 1
)
    THROW 510462, N'[FIELDMAP] Site asal tidak punya baris field-map aktif. Periksa nilai @FromSite.', 1;

BEGIN TRANSACTION;

DECLARE
    @PkName SYSNAME,
    @Sql    NVARCHAR(MAX),
    @Added  INT;

SELECT @PkName = kc.name
FROM sys.key_constraints AS kc
WHERE kc.parent_object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst')
  AND kc.type = N'PK';

IF @PkName IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes AS i
       INNER JOIN sys.index_columns AS ic
          ON ic.object_id = i.object_id
         AND ic.index_id = i.index_id
       INNER JOIN sys.columns AS c
          ON c.object_id = ic.object_id
         AND c.column_id = ic.column_id
       WHERE i.object_id = OBJECT_ID(N'dbo.ue_SMK069_pos_field_map_mst')
         AND i.is_primary_key = 1
         AND c.name = N'SiteRef'
   )
BEGIN
    SET @Sql =
        N'ALTER TABLE dbo.ue_SMK069_pos_field_map_mst DROP CONSTRAINT ' + QUOTENAME(@PkName) + N'; '
        + N'ALTER TABLE dbo.ue_SMK069_pos_field_map_mst ADD CONSTRAINT ' + QUOTENAME(@PkName)
        + N' PRIMARY KEY CLUSTERED (SiteRef, source_system, source_field);';

    EXEC sys.sp_executesql @Sql;

    PRINT N'[FIELDMAP] Kunci utama diubah: SiteRef ikut menjadi kunci.';
END;

INSERT INTO dbo.ue_SMK069_pos_field_map_mst
(
    source_system,
    source_field,
    target_field,
    is_required,
    priority_no,
    is_active,
    description,
    RowPointer,
    SiteRef
)
SELECT
    s.source_system,
    s.source_field,
    s.target_field,
    s.is_required,
    s.priority_no,
    s.is_active,
    s.description,
    NEWID(),
    @NewSite
FROM dbo.ue_SMK069_pos_field_map_mst AS s
WHERE s.SiteRef = @FromSite
  AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.ue_SMK069_pos_field_map_mst AS t
          WHERE t.SiteRef = @NewSite
            AND t.source_system = s.source_system
            AND t.source_field = s.source_field
      );

SET @Added = @@ROWCOUNT;

COMMIT TRANSACTION;

PRINT N'[FIELDMAP] Baris ditambahkan untuk site ' + @NewSite + N': ' + CONVERT(NVARCHAR(20), @Added);

/* Hasil: tiap site harus punya jumlah baris yang sama (36 untuk source_system POS). */
SELECT SiteRef, source_system, COUNT(*) AS jml, SUM(CAST(is_active AS INT)) AS aktif
FROM dbo.ue_SMK069_pos_field_map_mst
GROUP BY SiteRef, source_system
ORDER BY 1, 2;
