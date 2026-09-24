/* PROD migration artifact
   Source: database/patches/shipment/2026-09-11-smk069-21-one-minute-retry-1440-attempts.sql
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   SMK069 - Shipment Patch 21
   Retry every 1 minute, maximum 1440 attempts per DN
   -----------------------------------------------------------------------------
   Date    : 2026-09-11
   Scope   : Shipment Outbound SyteLine -> POS API only

   CONFIRMED BUSINESS REQUIREMENT
   ------------------------------
   POS team confirmed on 11 Sep 2026:
       retry interval : 1 minute
       max attempts   : 1440 per DN
       applies to     : all Shipment API failure responses

   IMPLEMENTATION
   --------------
   MaxAttempts          = 1440
   BackoffBaseMinutes   = 1
   BackoffCapMinutes    = 1

   Setting both Base and Cap to 1 intentionally turns the existing exponential
   backoff formula into a fixed one-minute retry eligibility window.

   The HOURLY business schedule row is retained for compatibility but its
   IntervalMinutes becomes 1 and its display name becomes "Every 1 Minute".

   IMPORTANT
   ---------
   * This patch does NOT change MaxShipments / MaxBatchSize.
     Max / Run remains an independent operational setting.
   * This patch does NOT enable a disabled scheduler.
   * This patch does NOT submit TaskMan.
   * This patch does NOT perform HTTP.
   * Existing retry history and API logs are preserved.
   * Login failure is still handled before any DN is sent; it does not consume
     per-DN retry attempts because no Shipment request was made.
   * TaskMan heartbeat must ALSO be 1 minute. That is form/TaskMan metadata,
     not this SQL policy patch.
   * Designed for Infor Apply Database: ONE executable batch, NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));

    IF OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst', N'U') IS NULL
        RAISERROR('ue_SMK069_shipment_api_config_mst tidak ditemukan.', 16, 1);

    IF COL_LENGTH(N'dbo.ue_SMK069_shipment_api_config_mst', N'MaxAttempts') IS NULL
       OR COL_LENGTH(N'dbo.ue_SMK069_shipment_api_config_mst', N'BackoffBaseMinutes') IS NULL
       OR COL_LENGTH(N'dbo.ue_SMK069_shipment_api_config_mst', N'BackoffCapMinutes') IS NULL
        RAISERROR('Kolom retry config belum lengkap. Patch 07+ diperlukan.', 16, 1);

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_api_config_mst
        WHERE SiteRef = @Site
          AND ApiName = N'SHIPMENT'
          AND IsActive = 1
    )
        RAISERROR('Config SHIPMENT aktif untuk current Site tidak ditemukan.', 16, 1);

    UPDATE dbo.ue_SMK069_shipment_api_config_mst
    SET MaxAttempts         = 1440,
        BackoffBaseMinutes  = 1,
        BackoffCapMinutes   = 1,
        UpdatedBy           = SUSER_SNAME(),
        RecordDate          = GETDATE()
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    IF OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst', N'U') IS NULL
        RAISERROR('ue_SMK069_shipment_schedule_mst tidak ditemukan. Patch 09+ diperlukan.', 16, 1);

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = @Site
          AND ScheduleCode = N'HOURLY'
    )
        RAISERROR('Schedule HOURLY current Site tidak ditemukan.', 16, 1);

    UPDATE dbo.ue_SMK069_shipment_schedule_mst
    SET ScheduleName    = N'Every 1 Minute',
        IntervalMinutes = 1,
        UpdatedBy       = SUSER_SNAME(),
        RecordDate      = GETDATE()
    WHERE SiteRef = @Site
      AND ScheduleCode = N'HOURLY';

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_api_config_mst
        WHERE SiteRef = @Site
          AND ApiName = N'SHIPMENT'
          AND IsActive = 1
          AND MaxAttempts = 1440
          AND BackoffBaseMinutes = 1
          AND BackoffCapMinutes = 1
    )
        RAISERROR('Post-assertion retry config gagal.', 16, 1);

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = @Site
          AND ScheduleCode = N'HOURLY'
          AND IntervalMinutes = 1
    )
        RAISERROR('Post-assertion schedule interval gagal.', 16, 1);

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 21 applied.';
    PRINT 'Retry policy: fixed 1 minute, MaxAttempts=1440 per DN.';
    PRINT 'Schedule HOURLY IntervalMinutes=1; name=Every 1 Minute.';
    PRINT 'Max / Run TIDAK diubah.';
    PRINT 'Scheduler enable/disable state TIDAK diubah.';
    PRINT 'TaskMan heartbeat harus diubah menjadi 1 menit melalui form REV6 lalu STOP/START ulang.';
    PRINT 'Patch ini TIDAK melakukan HTTP dan TIDAK menghapus history.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
