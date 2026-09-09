/* =============================================================================
   SMK069 - Patch 12 - Wait for Run Now background completion
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Object  : dbo.SMK069WaitShipmentRunCompletionSp
   Purpose : Allow the dashboard Run Now event to submit TaskMan asynchronously,
             then wait briefly for the selected schedule to complete before the
             form refreshes Schedule / Dashboard / Queue collections.

   IMPORTANT
   ---------
   - This does NOT perform HTTP.
   - This does NOT replace TaskMan.
   - It only polls ue_SMK069_shipment_schedule_mst for LastRunDate to advance.
   - The procedure returns success even when the wait times out, so the form can
     still refresh and show the latest available state.
   - Designed for Infor Apply Database: one CREATE OR ALTER statement, no GO.
   ============================================================================= */

CREATE OR ALTER PROCEDURE dbo.SMK069WaitShipmentRunCompletionSp
    @ScheduleCode       NVARCHAR(30),
    @PreviousLastRunDate DATETIME = NULL,
    @TimeoutSeconds     INT = 30,
    @Completed          INT OUTPUT,
    @Infobar            NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @Site SiteType,
        @Deadline DATETIME,
        @CurrentLastRunDate DATETIME,
        @RunState NCHAR(1),
        @LastRunStatus NCHAR(1);

    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @Completed = 0;
    SET @Infobar = NULL;
    SET @ScheduleCode = UPPER(NULLIF(LTRIM(RTRIM(@ScheduleCode)), N''));
    SET @TimeoutSeconds = CASE
        WHEN @TimeoutSeconds IS NULL OR @TimeoutSeconds < 1 THEN 30
        WHEN @TimeoutSeconds > 60 THEN 60
        ELSE @TimeoutSeconds
    END;

    IF @ScheduleCode IS NULL
    BEGIN
        SET @Infobar = N'Schedule Code wajib diisi.';
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = @Site
          AND ScheduleCode = @ScheduleCode
    )
    BEGIN
        SET @Infobar = CONCAT(N'Schedule ', @ScheduleCode, N' tidak ditemukan.');
        RETURN 16;
    END;

    SET @Deadline = DATEADD(SECOND, @TimeoutSeconds, GETDATE());

    WHILE GETDATE() < @Deadline
    BEGIN
        SELECT
            @CurrentLastRunDate = LastRunDate,
            @RunState = RunState,
            @LastRunStatus = LastRunStatus
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = @Site
          AND ScheduleCode = @ScheduleCode;

        IF @CurrentLastRunDate IS NOT NULL
           AND (
                @PreviousLastRunDate IS NULL
                OR @CurrentLastRunDate > @PreviousLastRunDate
           )
        BEGIN
            SET @Completed = 1;
            SET @Infobar = CONCAT(
                N'Run ', @ScheduleCode,
                N' selesai. Status=', ISNULL(@LastRunStatus, N'?'),
                N'; LastRunDate=', CONVERT(NVARCHAR(23), @CurrentLastRunDate, 121), N'.');
            RETURN 0;
        END;

        WAITFOR DELAY '00:00:01';
    END;

    SELECT
        @CurrentLastRunDate = LastRunDate,
        @RunState = RunState,
        @LastRunStatus = LastRunStatus
    FROM dbo.ue_SMK069_shipment_schedule_mst
    WHERE SiteRef = @Site
      AND ScheduleCode = @ScheduleCode;

    SET @Infobar = CONCAT(
        N'Background task masih diproses atau belum selesai setelah ',
        CONVERT(NVARCHAR(10), @TimeoutSeconds),
        N' detik. Dashboard tetap direfresh. RunState=',
        ISNULL(@RunState, N'?'),
        N'; LastStatus=', ISNULL(@LastRunStatus, N'?'), N'.');

    RETURN 0;
END;
