/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 6
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
