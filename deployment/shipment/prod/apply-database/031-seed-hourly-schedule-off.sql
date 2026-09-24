/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 4
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
