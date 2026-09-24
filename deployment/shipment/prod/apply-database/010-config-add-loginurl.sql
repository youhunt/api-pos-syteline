/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-07-shipment-scheduler-tables.sql
   Source batch: 1
   Generated to satisfy SyteLine Cloud Apply Database one-batch/no-GO execution.
   Do not add GO.
*/
/* =============================================================================
   SMK069 - Shipment Scheduler, Patch 07 (REVISI 2)
   -----------------------------------------------------------------------------
   Objects  : dbo.ue_SMK069_shipment_api_config_mst   (ALTER - tambah kolom)
              dbo.ue_SMK069_shipment_retry_mst        (BARU)
   Date     : 2026-09-08
   Design   : docs/29-shipment-scheduler.md

   REVISI 2 - hasil survei tenant 8 Sep
   -------------------------------------
   Revisi 1 membuat tabel konfigurasi baru bernama ue_SMK069_shipment_config_mst.
   Itu salah: tenant SUDAH punya ue_SMK069_shipment_api_config_mst, dibaca oleh
   SMK069GetShipmentApiConfigSp dengan kunci SiteRef + ApiName + IsActive. Dua
   tabel konfigurasi yang saling tidak tahu adalah kekacauan yang mahal
   dibereskan belakangan.

   Revisi ini hanya MENAMBAH kolom ke tabel yang sudah ada. Kolom lama tidak
   disentuh dan SMK069GetShipmentApiConfigSp tidak diubah, jadi apa pun yang
   sudah memakainya tetap jalan.

   Penamaan mengikuti tabel yang ada: PascalCase, dan UDT Mongoose
   (SiteType, UsernameType, CurrentDateType, RowPointerType, FlagNyType)
   seperti ue_SMK069_shipment_api_log_mst.

   KENAPA TABEL RETRY TETAP DIBUAT
   -------------------------------
   ue_SMK069_shipment_sender_run_mst mencatat per RUN - pending_count,
   sent_count, success_count. Itu ringkasan eksekusi, bukan status per shipment.
   Backoff butuh tahu "DN ini sudah gagal berapa kali dan boleh dicoba lagi
   kapan", dan itu per DN.

   ue_SMK069_shipment_api_log_mst.RetryCount juga tidak bisa dipakai: Prepare
   membuat baris log BARU setiap kali baris sebelumnya sudah error, jadi
   counter-nya tidak pernah lewat 1 untuk DN yang gagal berulang.

   TIDAK ADA KREDENSIAL DI SINI
   ----------------------------
   Kolom AuthValue yang sudah ada tidak dipakai untuk jalur Shipment. KACS
   butuh login yang menghasilkan token, dan token itu kedaluwarsa - satu yang
   diuji 7 Sep sudah lewat 11 hari. Menyimpannya di tabel berarti scheduler
   mati diam-diam saat token habis. Username dan password datang dari parameter
   task TaskMan, dan login dilakukan sekali per run.
   ============================================================================= */

/* =============================================================================
   1. TAMBAH KOLOM SCHEDULER KE TABEL KONFIGURASI YANG SUDAH ADA
      Semua NULL-able supaya baris lama (kalau nanti ada) tidak tertolak.
      Nilai efektifnya diberi default di prosedur pembaca, bukan di DDL.
   ============================================================================= */

IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'LoginUrl') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD LoginUrl NVARCHAR(1000) NULL;
