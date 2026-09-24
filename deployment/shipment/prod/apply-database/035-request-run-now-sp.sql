/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 8
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
