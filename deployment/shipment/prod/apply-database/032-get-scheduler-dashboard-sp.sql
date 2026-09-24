/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 5
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
