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
GO

IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'SuccessMode') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD SuccessMode NVARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'SchedulerEnabled') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD SchedulerEnabled TINYINT NULL;
GO

IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'MaxBatchSize') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD MaxBatchSize INT NULL;
GO

IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'MaxAttempts') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD MaxAttempts INT NULL;
GO

IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'BackoffBaseMinutes') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD BackoffBaseMinutes INT NULL;
GO

IF COL_LENGTH('dbo.ue_SMK069_shipment_api_config_mst', 'BackoffCapMinutes') IS NULL
    ALTER TABLE dbo.ue_SMK069_shipment_api_config_mst
        ADD BackoffCapMinutes INT NULL;
GO

/* =============================================================================
   2. TABEL STATUS PERCOBAAN PER SHIPMENT

      RetryState:
        P = pending, masih dalam jatah percobaan
        X = menyerah, hanya kembali kalau operator mengembalikannya
        S = berhasil, disimpan sebagai riwayat

      ShipmentId nvarchar(40) menyamai lebar kolom di tabel log, supaya
      P96325 dan penerusnya muat tanpa pemotongan diam-diam.
   ============================================================================= */

IF OBJECT_ID('dbo.ue_SMK069_shipment_retry_mst', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_shipment_retry_mst
    (
        SiteRef          SiteType       NOT NULL,
        ShipmentId       NVARCHAR(40)   NOT NULL,

        AttemptCount     INT            NOT NULL
            CONSTRAINT DF_SMK069_shipretry_cnt DEFAULT (0),
        RetryState       NCHAR(1)       NOT NULL
            CONSTRAINT DF_SMK069_shipretry_state DEFAULT (N'P'),

        FirstAttemptDate DATETIME       NULL,
        LastAttemptDate  DATETIME       NULL,
        NextAttemptDate  DATETIME       NULL,
        LastHttpCode     INT            NULL,
        LastError        NVARCHAR(1000) NULL,

        /* standar Mongoose, mengikuti ue_SMK069_shipment_api_log_mst */
        CreatedBy        UsernameType   NOT NULL
            CONSTRAINT DF_SMK069_shipretry_cb DEFAULT (SUSER_SNAME()),
        UpdatedBy        UsernameType   NOT NULL
            CONSTRAINT DF_SMK069_shipretry_ub DEFAULT (SUSER_SNAME()),
        CreateDate       CurrentDateType NOT NULL
            CONSTRAINT DF_SMK069_shipretry_cd DEFAULT (GETDATE()),
        RecordDate       CurrentDateType NOT NULL
            CONSTRAINT DF_SMK069_shipretry_rd DEFAULT (GETDATE()),
        RowPointer       RowPointerType NOT NULL ROWGUIDCOL
            CONSTRAINT DF_SMK069_shipretry_rp DEFAULT (NEWID()),
        NoteExistsFlag   FlagNyType     NOT NULL
            CONSTRAINT DF_SMK069_shipretry_nef DEFAULT (0),
        InWorkflow       FlagNyType     NOT NULL
            CONSTRAINT DF_SMK069_shipretry_iw DEFAULT (0),

        CONSTRAINT PK_ue_SMK069_shipment_retry_mst
            PRIMARY KEY CLUSTERED (SiteRef, ShipmentId),
        CONSTRAINT UQ_ue_SMK069_shipment_retry_rp
            UNIQUE (RowPointer),
        CONSTRAINT CK_ue_SMK069_shipment_retry_state
            CHECK (RetryState IN (N'P', N'X', N'S'))
    );

    CREATE NONCLUSTERED INDEX IX_ue_SMK069_shipment_retry_due
        ON dbo.ue_SMK069_shipment_retry_mst (SiteRef, RetryState, NextAttemptDate)
        INCLUDE (ShipmentId, AttemptCount);
END;
GO

/* =============================================================================
   3. BARIS KONFIGURASI

      Tabel ini KOSONG di tenant, jadi SMK069GetShipmentApiConfigSp selama ini
      selalu mengembalikan Success = 0. Baris berikut mengisinya.

      >>> PERIKSA EndpointUrl SEBELUM MENJALANKAN <<<
      Tim POS menyebut dua bentuk pada 7 Sep:
          https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
          https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
      Salah satunya yang berhasil di Postman. Pakai yang itu.

      SchedulerEnabled sengaja 0. Dinyalakan di langkah 8, setelah uji manual.
      AuthValue sengaja NULL - kredensial tidak disimpan di sini.
   ============================================================================= */

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
      AND ApiName = N'SHIPMENT'
)
BEGIN
    INSERT INTO dbo.ue_SMK069_shipment_api_config_mst
    (
        SiteRef, ApiName, EndpointUrl, HttpMethod, ContentType,
        AuthType, AuthHeader, AuthValue, TimeoutSeconds, IsActive,
        LoginUrl, SuccessMode, SchedulerEnabled,
        MaxBatchSize, MaxAttempts, BackoffBaseMinutes, BackoffCapMinutes
    )
    VALUES
    (
        RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0)),
        N'SHIPMENT',
        N'https://api-uat.pizzahut.co.id/inventory/v1/infor_dn',   -- PERIKSA
        N'POST',
        N'application/json',
        N'BEARER_LOGIN',          -- token diperoleh saat run, bukan disimpan
        N'Authorization',
        NULL,                     -- sengaja kosong
        60,
        1,                        -- IsActive: konfigurasi terbaca
        N'https://api-uat.pizzahut.co.id/service-auth/login-once',
        N'KACS_V1',
        0,                        -- SchedulerEnabled: MATI sampai langkah 8
        50,                       -- MaxBatchSize
        5,                        -- MaxAttempts
        15,                       -- BackoffBaseMinutes: 15, 30, 60, 120
        480                       -- BackoffCapMinutes
    );
END;
GO

/* =============================================================================
   VERIFIKASI - jalankan setelah Apply Database
   ============================================================================= */
/*
-- kolom baru sudah ada?
SELECT c.name AS kolom, t.name AS tipe, c.max_length, c.is_nullable
FROM sys.columns AS c
JOIN sys.types  AS t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.ue_SMK069_shipment_api_config_mst')
ORDER BY c.column_id;

-- baris konfigurasi terisi, tanpa membuka AuthValue
SELECT SiteRef, ApiName, IsActive, SchedulerEnabled, EndpointUrl, LoginUrl,
       SuccessMode, TimeoutSeconds, MaxBatchSize, MaxAttempts,
       BackoffBaseMinutes, BackoffCapMinutes,
       CASE WHEN AuthValue IS NULL THEN N'<kosong, benar>'
            ELSE N'<terisi - periksa kenapa>' END AS AuthValue_disamarkan
FROM dbo.ue_SMK069_shipment_api_config_mst;

-- tabel retry sudah ada dan masih kosong
SELECT COUNT(*) AS baris_retry FROM dbo.ue_SMK069_shipment_retry_mst;

-- SP lama masih membaca dengan benar setelah ALTER
DECLARE @EndpointUrl NVARCHAR(1000), @HttpMethod NVARCHAR(10),
        @ContentType NVARCHAR(100), @AuthType NVARCHAR(20),
        @AuthHeader NVARCHAR(100), @AuthValue NVARCHAR(2000),
        @TimeoutSeconds INT, @Success INT, @Infobar NVARCHAR(4000);

EXEC dbo.SMK069GetShipmentApiConfigSp
     @EndpointUrl OUTPUT, @HttpMethod OUTPUT, @ContentType OUTPUT,
     @AuthType OUTPUT, @AuthHeader OUTPUT, @AuthValue OUTPUT,
     @TimeoutSeconds OUTPUT, @Success OUTPUT, @Infobar OUTPUT;

SELECT @Success AS Success, @EndpointUrl AS EndpointUrl, @Infobar AS Infobar;
*/
