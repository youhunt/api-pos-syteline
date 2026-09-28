/* REFERENCE/FALLBACK ONLY FOR CLEAN PROD.
   Preferred path for this Mongoose-owned ue_SMK069_* table is SQL Tables /
   Mongoose metadata so standard metadata and table triggers are generated.
   Do not use this raw CREATE TABLE file for clean PROD unless explicitly
   using a controlled fallback and then repairing metadata with Update Current Table.
*/

/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 3
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   2. FORM-MANAGED SCHEDULE TABLE

   RunState:
     I = idle
     R = claimed/running

   LastRunStatus:
     N = never run
     S = completed with no failed shipment
     W = completed, but one or more shipments failed
     E = runner/system error

   Credentials are intentionally absent.
   ============================================================================= */
IF OBJECT_ID('dbo.ue_SMK069_shipment_schedule_mst', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ue_SMK069_shipment_schedule_mst
    (
        SiteRef          SiteType         NOT NULL,
        ScheduleCode     NVARCHAR(30)     NOT NULL,
        ScheduleName     NVARCHAR(100)    NOT NULL,
        IntervalMinutes  INT              NOT NULL,
        MaxShipments     INT              NULL,
        IsEnabled        FlagNyType       NOT NULL
            CONSTRAINT DF_SMK069_shipsched_enabled DEFAULT (0),

        NextRunDate      DATETIME         NULL,
        RunRequested     FlagNyType       NOT NULL
            CONSTRAINT DF_SMK069_shipsched_req DEFAULT (0),
        RunState         NCHAR(1)         NOT NULL
            CONSTRAINT DF_SMK069_shipsched_state DEFAULT (N'I'),
        LeaseUntil       DATETIME         NULL,

        LastStartDate    DATETIME         NULL,
        LastRunDate      DATETIME         NULL,
        LastRunStatus    NCHAR(1)         NOT NULL
            CONSTRAINT DF_SMK069_shipsched_laststatus DEFAULT (N'N'),
        LastCandidates   INT              NOT NULL
            CONSTRAINT DF_SMK069_shipsched_candidates DEFAULT (0),
        LastSucceeded    INT              NOT NULL
            CONSTRAINT DF_SMK069_shipsched_succeeded DEFAULT (0),
        LastFailed       INT              NOT NULL
            CONSTRAINT DF_SMK069_shipsched_failed DEFAULT (0),
        LastExhausted    INT              NOT NULL
            CONSTRAINT DF_SMK069_shipsched_exhausted DEFAULT (0),
        LastMessage      NVARCHAR(1000)   NULL,

        CreatedBy        UsernameType     NOT NULL
            CONSTRAINT DF_SMK069_shipsched_cb DEFAULT (SUSER_SNAME()),
        UpdatedBy        UsernameType     NOT NULL
            CONSTRAINT DF_SMK069_shipsched_ub DEFAULT (SUSER_SNAME()),
        CreateDate       CurrentDateType  NOT NULL
            CONSTRAINT DF_SMK069_shipsched_cd DEFAULT (GETDATE()),
        RecordDate       CurrentDateType  NOT NULL
            CONSTRAINT DF_SMK069_shipsched_rd DEFAULT (GETDATE()),
        RowPointer       RowPointerType   NOT NULL ROWGUIDCOL
            CONSTRAINT DF_SMK069_shipsched_rp DEFAULT (NEWID()),
        NoteExistsFlag   FlagNyType       NOT NULL
            CONSTRAINT DF_SMK069_shipsched_nef DEFAULT (0),
        InWorkflow       FlagNyType       NOT NULL
            CONSTRAINT DF_SMK069_shipsched_iw DEFAULT (0),

        CONSTRAINT PK_ue_SMK069_shipment_schedule_mst
            PRIMARY KEY CLUSTERED (SiteRef, ScheduleCode),
        CONSTRAINT UQ_ue_SMK069_shipment_schedule_rp
            UNIQUE (RowPointer),
        CONSTRAINT CK_ue_SMK069_shipment_schedule_interval
            CHECK (IntervalMinutes BETWEEN 1 AND 10080),
        CONSTRAINT CK_ue_SMK069_shipment_schedule_runstate
            CHECK (RunState IN (N'I', N'R')),
        CONSTRAINT CK_ue_SMK069_shipment_schedule_laststatus
            CHECK (LastRunStatus IN (N'N', N'S', N'W', N'E'))
    );

    CREATE NONCLUSTERED INDEX IX_ue_SMK069_shipment_schedule_due
        ON dbo.ue_SMK069_shipment_schedule_mst
           (SiteRef, IsEnabled, NextRunDate, RunRequested)
        INCLUDE (ScheduleCode, IntervalMinutes, MaxShipments, RunState, LeaseUntil);
END;
