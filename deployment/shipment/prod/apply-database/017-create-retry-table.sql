/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-07-shipment-scheduler-tables.sql
   Source batch: 8
   Generated to satisfy SyteLine Cloud Apply Database one-batch/no-GO execution.
   Do not add GO.
*/
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
