/* =============================================================================
   SMK069 - Shipment Scheduler Control Center, Patch 09
   -----------------------------------------------------------------------------
   Objects  : dbo.ue_SMK069_shipment_schedule_mst        (NEW)
              dbo.SMK069GetShipmentSchedulerDashboardSp  (NEW)
              dbo.SMK069SaveShipmentScheduleSp            (NEW)
              dbo.SMK069SetShipmentSchedulerEnabledSp     (NEW)
              dbo.SMK069RequestShipmentRunNowSp           (NEW)
              dbo.SMK069ResetShipmentRetrySp              (NEW)
              dbo.SMK069ClaimDueShipmentScheduleSp        (NEW)
              dbo.SMK069CompleteShipmentScheduleSp        (NEW)
   Date     : 2026-09-08
   Design   : forms/02-SMK069ShipmentScheduler.md

   IMPORTANT
   ---------
   Patch 07 revision 2 added scheduler columns to the EXISTING
   ue_SMK069_shipment_api_config_mst. In a tenant that already had the SHIPMENT
   row, those newly added nullable columns stayed NULL because the INSERT branch
   was skipped. This patch normalizes only the NULL scheduler fields; it does
   NOT overwrite EndpointUrl, AuthValue, HttpMethod, or any pre-existing API
   setting.

   The form never asks for or stores the POS password. "Run Now" only marks a
   schedule due. A background TaskMan caller later consumes the due schedule
   with credentials supplied as TaskMan parameters.
   ============================================================================= */

SET NOCOUNT ON;
GO

/* =============================================================================
   1. NORMALIZE THE EXISTING SHIPMENT CONFIG ROW
   ============================================================================= */
DECLARE @Site SiteType;
SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
EXEC SetSiteSp @Site, NULL;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
)
BEGIN
    RAISERROR(
        'SHIPMENT config row is missing. Apply Patch 07 first.',
        16, 1
    );
    RETURN;
END;

UPDATE dbo.ue_SMK069_shipment_api_config_mst
SET LoginUrl            = COALESCE(NULLIF(LTRIM(RTRIM(LoginUrl)), N''),
                                   N'https://api-uat.pizzahut.co.id/service-auth/login-once'),
    SuccessMode         = COALESCE(NULLIF(LTRIM(RTRIM(SuccessMode)), N''), N'KACS_V1'),
    SchedulerEnabled    = COALESCE(SchedulerEnabled, 0),
    MaxBatchSize        = COALESCE(NULLIF(MaxBatchSize, 0), 50),
    MaxAttempts         = COALESCE(NULLIF(MaxAttempts, 0), 5),
    BackoffBaseMinutes  = COALESCE(NULLIF(BackoffBaseMinutes, 0), 15),
    BackoffCapMinutes   = COALESCE(NULLIF(BackoffCapMinutes, 0), 480),
    UpdatedBy           = SUSER_SNAME(),
    RecordDate          = GETDATE()
WHERE SiteRef = @Site
  AND ApiName = N'SHIPMENT';
GO

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
GO

/* Seed one understandable schedule, but keep it OFF until UAT is complete. */
DECLARE @Site SiteType;
SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
EXEC SetSiteSp @Site, NULL;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ue_SMK069_shipment_schedule_mst
    WHERE SiteRef = @Site
      AND ScheduleCode = N'HOURLY'
)
BEGIN
    INSERT INTO dbo.ue_SMK069_shipment_schedule_mst
    (
        SiteRef, ScheduleCode, ScheduleName,
        IntervalMinutes, MaxShipments, IsEnabled,
        NextRunDate
    )
    VALUES
    (
        @Site, N'HOURLY', N'Every 60 Minutes',
        60, NULL, 0,
        NULL
    );
END;
GO

/* =============================================================================
   3. DASHBOARD READER
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069GetShipmentSchedulerDashboardSp
    @MasterEnabled       INT            OUTPUT,
    @ApiActive           INT            OUTPUT,
    @ScheduleCount       INT            OUTPUT,
    @ActiveScheduleCount INT            OUTPUT,
    @NextRunDate         DATETIME       OUTPUT,
    @ReadyCount          INT            OUTPUT,
    @WaitingBackoffCount INT            OUTPUT,
    @ExhaustedCount      INT            OUTPUT,
    @SucceededToday      INT            OUTPUT,
    @FailedToday         INT            OUTPUT,
    @Infobar             NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType, @MaxAttempts INT;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SELECT
        @MasterEnabled       = 0,
        @ApiActive           = 0,
        @ScheduleCount       = 0,
        @ActiveScheduleCount = 0,
        @NextRunDate         = NULL,
        @ReadyCount          = 0,
        @WaitingBackoffCount = 0,
        @ExhaustedCount      = 0,
        @SucceededToday      = 0,
        @FailedToday         = 0,
        @Infobar             = NULL;

    SELECT TOP (1)
        @MasterEnabled = ISNULL(SchedulerEnabled, 0),
        @ApiActive     = ISNULL(IsActive, 0),
        @MaxAttempts   = COALESCE(NULLIF(MaxAttempts, 0), 5)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT';

    IF @MaxAttempts IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] Konfigurasi SHIPMENT untuk Site ', @Site, N' belum ada.');
        RETURN 16;
    END;

    SELECT
        @ScheduleCount       = COUNT(*),
        @ActiveScheduleCount = COALESCE(SUM(CASE WHEN IsEnabled = 1 THEN 1 ELSE 0 END), 0),
        @NextRunDate         = MIN(CASE WHEN IsEnabled = 1 THEN NextRunDate END)
    FROM dbo.ue_SMK069_shipment_schedule_mst
    WHERE SiteRef = @Site;

    SELECT DISTINCT
        LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))) AS ShipmentId
    INTO #Candidate
    FROM dbo.SMK069_ShipmentAPI_mst AS v
    WHERE v.site_ref = @Site
      AND ISNULL(v.Api_post, 0) = 0
      AND ISNULL(v.shipment_qty, 0) > 0
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))), N'') IS NOT NULL;

    SELECT
        c.ShipmentId,
        ISNULL(r.AttemptCount, 0) AS AttemptCount,
        ISNULL(r.RetryState, N'P') AS RetryState,
        r.NextAttemptDate
    INTO #Scored
    FROM #Candidate AS c
    LEFT JOIN dbo.ue_SMK069_shipment_retry_mst AS r
      ON r.SiteRef = @Site
     AND r.ShipmentId = c.ShipmentId;

    SELECT @ReadyCount = COUNT(*)
    FROM #Scored
    WHERE RetryState = N'P'
      AND AttemptCount < @MaxAttempts
      AND (NextAttemptDate IS NULL OR NextAttemptDate <= GETDATE());

    SELECT @WaitingBackoffCount = COUNT(*)
    FROM #Scored
    WHERE RetryState = N'P'
      AND AttemptCount < @MaxAttempts
      AND NextAttemptDate > GETDATE();

    SELECT @ExhaustedCount = COUNT(*)
    FROM #Scored
    WHERE RetryState = N'X'
       OR AttemptCount >= @MaxAttempts;

    SELECT @SucceededToday = COUNT(*)
    FROM dbo.ue_SMK069_shipment_retry_mst
    WHERE SiteRef = @Site
      AND RetryState = N'S'
      AND LastAttemptDate >= CONVERT(DATE, GETDATE());

    SELECT @FailedToday = COUNT(*)
    FROM dbo.ue_SMK069_shipment_retry_mst
    WHERE SiteRef = @Site
      AND RetryState IN (N'P', N'X')
      AND LastAttemptDate >= CONVERT(DATE, GETDATE())
      AND NULLIF(LastError, N'') IS NOT NULL;

    DROP TABLE #Scored;
    DROP TABLE #Candidate;

    SET @Infobar = CONCAT(
        N'Master=', CASE WHEN @MasterEnabled = 1 THEN N'ON' ELSE N'OFF' END,
        N'; schedule aktif=', CONVERT(NVARCHAR(20), @ActiveScheduleCount),
        N'; siap kirim=', CONVERT(NVARCHAR(20), @ReadyCount),
        N'; backoff=', CONVERT(NVARCHAR(20), @WaitingBackoffCount),
        N'; exhausted=', CONVERT(NVARCHAR(20), @ExhaustedCount), N'.');

    RETURN 0;
END;
GO

/* =============================================================================
   4. SAVE / UPSERT SCHEDULE
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069SaveShipmentScheduleSp
    @ScheduleCode    NVARCHAR(30),
    @ScheduleName    NVARCHAR(100),
    @IntervalMinutes INT,
    @MaxShipments    INT = NULL,
    @IsEnabled       INT,
    @StartAt         DATETIME = NULL,
    @Success         INT OUTPUT,
    @Infobar         NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @Success = 0;
    SET @Infobar = NULL;
    SET @ScheduleCode = UPPER(NULLIF(LTRIM(RTRIM(@ScheduleCode)), N''));
    SET @ScheduleName = NULLIF(LTRIM(RTRIM(@ScheduleName)), N'');

    IF @ScheduleCode IS NULL OR @ScheduleName IS NULL
    BEGIN
        SET @Infobar = N'Schedule Code dan Schedule Name wajib diisi.';
        RETURN 16;
    END;

    IF @IntervalMinutes IS NULL OR @IntervalMinutes < 1 OR @IntervalMinutes > 10080
    BEGIN
        SET @Infobar = N'Interval harus 1 sampai 10080 menit.';
        RETURN 16;
    END;

    IF @MaxShipments IS NOT NULL AND @MaxShipments <= 0
    BEGIN
        SET @Infobar = N'Max Shipments harus lebih dari 0 atau dikosongkan.';
        RETURN 16;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = @Site
          AND ScheduleCode = @ScheduleCode
    )
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_schedule_mst
        SET ScheduleName    = @ScheduleName,
            IntervalMinutes = @IntervalMinutes,
            MaxShipments    = @MaxShipments,
            IsEnabled       = CASE WHEN @IsEnabled = 1 THEN 1 ELSE 0 END,
            NextRunDate     =
                CASE
                    WHEN @IsEnabled <> 1 THEN NULL
                    WHEN @StartAt IS NOT NULL THEN @StartAt
                    WHEN IsEnabled = 0 OR NextRunDate IS NULL
                        THEN DATEADD(MINUTE, @IntervalMinutes, GETDATE())
                    ELSE NextRunDate
                END,
            RunRequested = CASE WHEN @IsEnabled = 1 THEN RunRequested ELSE 0 END,
            RunState     = CASE WHEN @IsEnabled = 1 THEN RunState ELSE N'I' END,
            LeaseUntil   = CASE WHEN @IsEnabled = 1 THEN LeaseUntil ELSE NULL END,
            UpdatedBy    = SUSER_SNAME(),
            RecordDate   = GETDATE()
        WHERE SiteRef = @Site
          AND ScheduleCode = @ScheduleCode;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.ue_SMK069_shipment_schedule_mst
        (
            SiteRef, ScheduleCode, ScheduleName,
            IntervalMinutes, MaxShipments, IsEnabled, NextRunDate
        )
        VALUES
        (
            @Site, @ScheduleCode, @ScheduleName,
            @IntervalMinutes, @MaxShipments,
            CASE WHEN @IsEnabled = 1 THEN 1 ELSE 0 END,
            CASE
                WHEN @IsEnabled = 1
                    THEN COALESCE(@StartAt, DATEADD(MINUTE, @IntervalMinutes, GETDATE()))
                ELSE NULL
            END
        );
    END;

    SET @Success = 1;
    SET @Infobar = CONCAT(
        N'Schedule ', @ScheduleCode, N' tersimpan. Status ',
        CASE WHEN @IsEnabled = 1 THEN N'AKTIF' ELSE N'NONAKTIF' END, N'.');
    RETURN 0;
END;
GO

/* =============================================================================
   5. MASTER SWITCH
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069SetShipmentSchedulerEnabledSp
    @Enabled INT,
    @Success INT OUTPUT,
    @Infobar NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @Success = 0;
    SET @Infobar = NULL;

    UPDATE dbo.ue_SMK069_shipment_api_config_mst
    SET SchedulerEnabled = CASE WHEN @Enabled = 1 THEN 1 ELSE 0 END,
        UpdatedBy = SUSER_SNAME(),
        RecordDate = GETDATE()
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = N'Konfigurasi SHIPMENT aktif tidak ditemukan.';
        RETURN 16;
    END;

    SET @Success = 1;
    SET @Infobar = CASE WHEN @Enabled = 1
        THEN N'Master Shipment Scheduler ON.'
        ELSE N'Master Shipment Scheduler OFF.'
    END;
    RETURN 0;
END;
GO

/* =============================================================================
   6. RUN NOW = mark a schedule due; NO credential is accepted from the form.
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069RequestShipmentRunNowSp
    @ScheduleCode NVARCHAR(30),
    @Success      INT OUTPUT,
    @Infobar      NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType, @MasterEnabled INT;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @Success = 0;
    SET @Infobar = NULL;
    SET @ScheduleCode = UPPER(NULLIF(LTRIM(RTRIM(@ScheduleCode)), N''));

    SELECT TOP (1) @MasterEnabled = ISNULL(SchedulerEnabled, 0)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    IF ISNULL(@MasterEnabled, 0) <> 1
    BEGIN
        SET @Infobar = N'Master Shipment Scheduler masih OFF. Aktifkan master switch lebih dulu.';
        RETURN 16;
    END;

    UPDATE dbo.ue_SMK069_shipment_schedule_mst
    SET RunRequested = 1,
        NextRunDate  = GETDATE(),
        UpdatedBy    = SUSER_SNAME(),
        RecordDate   = GETDATE()
    WHERE SiteRef = @Site
      AND ScheduleCode = @ScheduleCode
      AND IsEnabled = 1;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = N'Schedule tidak ditemukan atau masih NONAKTIF.';
        RETURN 16;
    END;

    SET @Success = 1;
    SET @Infobar = CONCAT(
        N'Schedule ', @ScheduleCode,
        N' ditandai Run Now. Background runner akan mengambilnya pada polling berikutnya.');
    RETURN 0;
END;
GO

/* =============================================================================
   7. RESET ONE EXHAUSTED/PENDING DN AFTER OPERATOR FIXES THE CAUSE
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069ResetShipmentRetrySp
    @DN_No   NVARCHAR(40),
    @Success INT OUTPUT,
    @Infobar NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @Success = 0;
    SET @Infobar = NULL;
    SET @DN_No = NULLIF(LTRIM(RTRIM(@DN_No)), N'');

    IF @DN_No IS NULL
    BEGIN
        SET @Infobar = N'DN No wajib diisi.';
        RETURN 16;
    END;

    UPDATE dbo.ue_SMK069_shipment_retry_mst
    SET AttemptCount    = 0,
        RetryState      = N'P',
        NextAttemptDate = NULL,
        UpdatedBy       = SUSER_SNAME(),
        RecordDate      = GETDATE()
    WHERE SiteRef = @Site
      AND ShipmentId = @DN_No;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = CONCAT(N'DN ', @DN_No, N' belum memiliki retry state.');
        RETURN 16;
    END;

    SET @Success = 1;
    SET @Infobar = CONCAT(
        N'DN ', @DN_No,
        N' dikembalikan ke antrean. Error terakhir tetap disimpan untuk audit.');
    RETURN 0;
END;
GO

/* =============================================================================
   8. BACKGROUND RUNNER: CLAIM ONE DUE SCHEDULE
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069ClaimDueShipmentScheduleSp
    @ScheduleCode NVARCHAR(30)   OUTPUT,
    @MaxShipments INT            OUTPUT,
    @HasWork      INT            OUTPUT,
    @Infobar      NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @Site SiteType,
        @MasterEnabled INT,
        @ApiActive INT,
        @CfgMaxBatch INT;

    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SELECT
        @ScheduleCode = NULL,
        @MaxShipments = 0,
        @HasWork = 0,
        @Infobar = NULL;

    SELECT TOP (1)
        @MasterEnabled = ISNULL(SchedulerEnabled, 0),
        @ApiActive     = ISNULL(IsActive, 0),
        @CfgMaxBatch   = COALESCE(NULLIF(MaxBatchSize, 0), 50)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT';

    IF ISNULL(@ApiActive, 0) <> 1
    BEGIN
        SET @Infobar = N'API SHIPMENT tidak aktif; tidak ada schedule yang diklaim.';
        RETURN 0;
    END;

    IF ISNULL(@MasterEnabled, 0) <> 1
    BEGIN
        SET @Infobar = N'Master Shipment Scheduler OFF; tidak ada schedule yang diklaim.';
        RETURN 0;
    END;

    BEGIN TRANSACTION;

    SELECT TOP (1)
        @ScheduleCode = ScheduleCode,
        @MaxShipments = COALESCE(NULLIF(MaxShipments, 0), @CfgMaxBatch, 50)
    FROM dbo.ue_SMK069_shipment_schedule_mst WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE SiteRef = @Site
      AND IsEnabled = 1
      AND
      (
          RunRequested = 1
          OR NextRunDate IS NULL
          OR NextRunDate <= GETDATE()
      )
      AND
      (
          RunState <> N'R'
          OR LeaseUntil IS NULL
          OR LeaseUntil <= GETDATE()
      )
    ORDER BY
        CASE WHEN RunRequested = 1 THEN 0 ELSE 1 END,
        NextRunDate,
        ScheduleCode;

    IF @ScheduleCode IS NOT NULL
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_schedule_mst
        SET RunRequested = 0,
            RunState     = N'R',
            LeaseUntil   = DATEADD(MINUTE, 15, GETDATE()),
            LastStartDate = GETDATE(),
            UpdatedBy    = SUSER_SNAME(),
            RecordDate   = GETDATE()
        WHERE SiteRef = @Site
          AND ScheduleCode = @ScheduleCode;

        SET @HasWork = 1;
    END;

    COMMIT TRANSACTION;

    SET @Infobar =
        CASE WHEN @HasWork = 1
            THEN CONCAT(
                N'Schedule ', @ScheduleCode,
                N' diklaim. Max Shipments=', CONVERT(NVARCHAR(20), @MaxShipments), N'.')
            ELSE N'Tidak ada Shipment schedule yang jatuh tempo.'
        END;

    RETURN 0;
END;
GO

/* =============================================================================
   9. BACKGROUND RUNNER: COMPLETE THE CLAIM AND PLAN THE NEXT RUN
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069CompleteShipmentScheduleSp
    @ScheduleCode NVARCHAR(30),
    @ResultCode   INT,
    @Candidates   INT,
    @Succeeded    INT,
    @Failed       INT,
    @Exhausted    INT,
    @Message      NVARCHAR(1000) = NULL,
    @Success      INT OUTPUT,
    @Infobar      NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @Success = 0;
    SET @Infobar = NULL;
    SET @ScheduleCode = UPPER(NULLIF(LTRIM(RTRIM(@ScheduleCode)), N''));

    UPDATE dbo.ue_SMK069_shipment_schedule_mst
    SET LastRunDate     = GETDATE(),
        LastRunStatus   =
            CASE
                WHEN @ResultCode <> 0 THEN N'E'
                WHEN ISNULL(@Failed, 0) > 0 THEN N'W'
                ELSE N'S'
            END,
        LastCandidates  = ISNULL(@Candidates, 0),
        LastSucceeded   = ISNULL(@Succeeded, 0),
        LastFailed      = ISNULL(@Failed, 0),
        LastExhausted   = ISNULL(@Exhausted, 0),
        LastMessage     = LEFT(@Message, 1000),
        NextRunDate     =
            CASE
                WHEN IsEnabled = 1
                    THEN DATEADD(MINUTE, IntervalMinutes, GETDATE())
                ELSE NULL
            END,
        RunState        = N'I',
        LeaseUntil      = NULL,
        UpdatedBy       = SUSER_SNAME(),
        RecordDate      = GETDATE()
    WHERE SiteRef = @Site
      AND ScheduleCode = @ScheduleCode;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = N'Schedule yang akan diselesaikan tidak ditemukan.';
        RETURN 16;
    END;

    SET @Success = 1;
    SET @Infobar = CONCAT(
        N'Schedule ', @ScheduleCode,
        N' selesai. Kandidat=', CONVERT(NVARCHAR(20), ISNULL(@Candidates, 0)),
        N'; sukses=', CONVERT(NVARCHAR(20), ISNULL(@Succeeded, 0)),
        N'; gagal=', CONVERT(NVARCHAR(20), ISNULL(@Failed, 0)),
        N'; exhausted=', CONVERT(NVARCHAR(20), ISNULL(@Exhausted, 0)), N'.');
    RETURN 0;
END;
GO

/* =============================================================================
   10. VERIFICATION
   ============================================================================= */
/*
SELECT SiteRef, ApiName, IsActive, SchedulerEnabled,
       EndpointUrl, LoginUrl, SuccessMode,
       TimeoutSeconds, MaxBatchSize, MaxAttempts,
       BackoffBaseMinutes, BackoffCapMinutes
FROM dbo.ue_SMK069_shipment_api_config_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ApiName = N'SHIPMENT';

SELECT SiteRef, ScheduleCode, ScheduleName, IntervalMinutes, MaxShipments,
       IsEnabled, NextRunDate, RunRequested, RunState,
       LastRunDate, LastRunStatus,
       LastCandidates, LastSucceeded, LastFailed, LastExhausted, LastMessage
FROM dbo.ue_SMK069_shipment_schedule_mst
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
ORDER BY ScheduleCode;

DECLARE
    @MasterEnabled INT, @ApiActive INT, @ScheduleCount INT,
    @ActiveScheduleCount INT, @NextRunDate DATETIME,
    @ReadyCount INT, @WaitingBackoffCount INT, @ExhaustedCount INT,
    @SucceededToday INT, @FailedToday INT, @Infobar NVARCHAR(4000);

EXEC dbo.SMK069GetShipmentSchedulerDashboardSp
     @MasterEnabled OUTPUT, @ApiActive OUTPUT,
     @ScheduleCount OUTPUT, @ActiveScheduleCount OUTPUT, @NextRunDate OUTPUT,
     @ReadyCount OUTPUT, @WaitingBackoffCount OUTPUT, @ExhaustedCount OUTPUT,
     @SucceededToday OUTPUT, @FailedToday OUTPUT, @Infobar OUTPUT;

SELECT @MasterEnabled AS MasterEnabled,
       @ApiActive AS ApiActive,
       @ScheduleCount AS ScheduleCount,
       @ActiveScheduleCount AS ActiveScheduleCount,
       @NextRunDate AS NextRunDate,
       @ReadyCount AS ReadyCount,
       @WaitingBackoffCount AS WaitingBackoffCount,
       @ExhaustedCount AS ExhaustedCount,
       @SucceededToday AS SucceededToday,
       @FailedToday AS FailedToday,
       @Infobar AS Infobar;
*/
