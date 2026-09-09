/* =============================================================================
   SMK069 - Shipment Patch 17
   Arm controlled one-DN UAT for P96331 without sending HTTP
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Scope   : Shipment Outbound SyteLine -> POS API only

   PURPOSE
   -------
   Prepare a deterministic/safe scheduler state before the first controlled UAT
   after Patch 14/15/16, while keeping the master scheduler OFF.

   Tenant evidence before this patch:

       EndpointUrl      = https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn
       SchedulerEnabled = 0

       HOURLY MaxShipments = NULL
       HOURLY IsEnabled    = 1
       HOURLY RunRequested = 0
       HOURLY RunState     = I

       P96331 AttemptCount    = 3
       P96331 RetryState      = P
       P96331 NextAttemptDate = 2026-09-09 09:24 (tenant display)
       P96331 LastHttpCode    = 0

   SAFETY
   ------
   * Does NOT invoke HTTP.
   * Does NOT turn the master scheduler ON.
   * Does NOT set RunRequested = 1.
   * Does NOT reset any DN except P96331.
   * Parks HOURLY NextRunDate one day in the future so merely turning master ON
     later cannot immediately claim an already-due schedule before Run Now.
   * Keeps historical LastHttpCode / LastError for audit, matching the existing
     SMK069ResetShipmentRetrySp reset semantics.
   * One executable Apply Database batch; NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Site NVARCHAR(8);
    DECLARE @ExpectedEndpoint NVARCHAR(500);
    DECLARE @MasterEnabled INT;

    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    SET @ExpectedEndpoint = N'https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn';

    SELECT TOP (1)
        @MasterEnabled = ISNULL(SchedulerEnabled, 0)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    IF @MasterEnabled IS NULL
    BEGIN
        RAISERROR('Patch 17: config SHIPMENT aktif tidak ditemukan untuk Site saat ini.', 16, 1);
    END;

    IF @MasterEnabled <> 0
    BEGIN
        RAISERROR('Patch 17 dihentikan: Master Scheduler harus OFF sebelum controlled UAT di-arm.', 16, 1);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_api_config_mst
        WHERE SiteRef = @Site
          AND ApiName = N'SHIPMENT'
          AND IsActive = 1
          AND EndpointUrl = @ExpectedEndpoint
    )
    BEGIN
        RAISERROR('Patch 17 dihentikan: EndpointUrl belum sesuai Patch 16 target inventory-phi/infor_dn.', 16, 1);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = @Site
          AND ScheduleCode = N'HOURLY'
    )
    BEGIN
        RAISERROR('Patch 17: schedule HOURLY tidak ditemukan.', 16, 1);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_retry_mst
        WHERE SiteRef = @Site
          AND ShipmentId = N'P96331'
    )
    BEGIN
        RAISERROR('Patch 17: retry state P96331 tidak ditemukan.', 16, 1);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.SMK069_ShipmentAPI_mst
        WHERE site_ref = @Site
          AND LTRIM(RTRIM(CONVERT(NVARCHAR(40), DN_No))) = N'P96331'
          AND ISNULL(Api_post, 0) = 0
          AND ISNULL(shipment_qty, 0) > 0
    )
    BEGIN
        RAISERROR('Patch 17: P96331 tidak lagi eligible di Shipment View (Api_post/qty/DN).', 16, 1);
    END;

    UPDATE dbo.ue_SMK069_shipment_schedule_mst
    SET MaxShipments   = 1,
        IsEnabled      = 1,
        RunRequested   = 0,
        RunState       = N'I',
        LeaseUntil     = NULL,
        NextRunDate    = DATEADD(DAY, 1, GETDATE()),
        UpdatedBy      = SUSER_SNAME(),
        RecordDate     = GETDATE()
    WHERE SiteRef = @Site
      AND ScheduleCode = N'HOURLY';

    IF @@ROWCOUNT <> 1
    BEGIN
        RAISERROR('Patch 17 gagal meng-arm tepat satu schedule HOURLY.', 16, 1);
    END;

    UPDATE dbo.ue_SMK069_shipment_retry_mst
    SET AttemptCount    = 0,
        RetryState      = N'P',
        NextAttemptDate = NULL,
        UpdatedBy       = SUSER_SNAME(),
        RecordDate      = GETDATE()
    WHERE SiteRef = @Site
      AND ShipmentId = N'P96331';

    IF @@ROWCOUNT <> 1
    BEGIN
        RAISERROR('Patch 17 gagal mereset tepat satu retry row P96331.', 16, 1);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_schedule_mst
        WHERE SiteRef = @Site
          AND ScheduleCode = N'HOURLY'
          AND MaxShipments = 1
          AND IsEnabled = 1
          AND RunRequested = 0
          AND RunState = N'I'
          AND NextRunDate > GETDATE()
    )
    BEGIN
        RAISERROR('Patch 17 post-assertion gagal pada schedule HOURLY.', 16, 1);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_retry_mst
        WHERE SiteRef = @Site
          AND ShipmentId = N'P96331'
          AND AttemptCount = 0
          AND RetryState = N'P'
          AND NextAttemptDate IS NULL
    )
    BEGIN
        RAISERROR('Patch 17 post-assertion gagal pada retry P96331.', 16, 1);
    END;

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 17 applied.';
    PRINT 'Master Scheduler tetap OFF.';
    PRINT 'HOURLY MaxShipments=1, IsEnabled=1, RunRequested=0, RunState=I.';
    PRINT 'HOURLY NextRunDate diparkir +1 hari untuk mencegah auto-claim sebelum Run Now.';
    PRINT 'P96331 AttemptCount=0, RetryState=P, NextAttemptDate=NULL.';
    PRINT 'Patch ini TIDAK melakukan HTTP call.';
    PRINT 'LANGKAH BERIKUT: verifikasi ranking candidate sebelum Master Scheduler ON.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
