/* SMK069 Shipment PROD emergency stop
   Apply Database: ONE executable batch, NO GO.

   This stops the business eligibility gates immediately.
   Then use STOP SCHEDULER on the form to remove a WAITING recurring TaskMan
   instance when applicable.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));

    UPDATE dbo.ue_SMK069_shipment_api_config_mst
    SET SchedulerEnabled = 0,
        UpdatedBy = SUSER_SNAME(),
        RecordDate = GETDATE()
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    UPDATE dbo.ue_SMK069_shipment_schedule_mst
    SET IsEnabled = 0,
        RunRequested = 0,
        UpdatedBy = SUSER_SNAME(),
        RecordDate = GETDATE()
    WHERE SiteRef = @Site
      AND ScheduleCode = N'HOURLY';

    COMMIT TRANSACTION;
    PRINT 'OK - Shipment scheduler business gates are OFF.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
