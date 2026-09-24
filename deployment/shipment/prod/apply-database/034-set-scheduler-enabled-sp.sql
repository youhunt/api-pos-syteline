/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 7
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
