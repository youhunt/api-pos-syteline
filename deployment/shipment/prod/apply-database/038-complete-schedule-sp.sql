/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 11
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
