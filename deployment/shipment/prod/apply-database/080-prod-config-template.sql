/* =============================================================================
   SMK069 Shipment PROD configuration template
   Apply Database: ONE executable batch, NO GO.

   REQUIRED BEFORE EXECUTION
   -------------------------
   Confirmed PROD URLs:
     LoginUrl    = https://api-prod.pizzahut.co.id/service-auth/login-once
     EndpointUrl = https://api-prod.pizzahut.co.id/inventory-phi/v1/infor_dn

   Do NOT place username/password in this script or GitHub.

   SAFE CUTOVER STATE
   ------------------
   * API config active
   * Master SchedulerEnabled = 0
   * Business schedule IsEnabled = 0
   * MaxShipments = 1 for controlled PROD smoke test
   * Retry = fixed 1 minute, max 1440
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE
        @Site SiteType,
        @LoginUrl NVARCHAR(1000),
        @EndpointUrl NVARCHAR(1000),
        @ActiveCount INT;

    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    SET @LoginUrl = N'https://api-prod.pizzahut.co.id/service-auth/login-once';
    SET @EndpointUrl = N'https://api-prod.pizzahut.co.id/inventory-phi/v1/infor_dn';

    IF CHARINDEX(N'__PROD_', @LoginUrl) > 0 OR CHARINDEX(N'__PROD_', @EndpointUrl) > 0
        RAISERROR('Ganti placeholder PROD LoginUrl dan EndpointUrl sebelum Apply Database.', 16, 1);

    IF @LoginUrl LIKE N'%api-uat%' OR @EndpointUrl LIKE N'%api-uat%'
        RAISERROR('URL UAT terdeteksi. PROD config dibatalkan.', 16, 1);

    IF OBJECT_ID(N'dbo.ue_SMK069_shipment_api_config_mst', N'U') IS NULL
        RAISERROR('ue_SMK069_shipment_api_config_mst tidak ditemukan. Baseline Shipment wajib dimigrasikan dulu.', 16, 1);

    IF OBJECT_ID(N'dbo.ue_SMK069_shipment_schedule_mst', N'U') IS NULL
        RAISERROR('ue_SMK069_shipment_schedule_mst tidak ditemukan. Apply scheduler schema dulu.', 16, 1);

    SELECT @ActiveCount = COUNT(*)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    IF @ActiveCount > 1
        RAISERROR('Lebih dari satu config SHIPMENT aktif untuk Site ini. Rapikan sebelum migrasi PROD.', 16, 1);

    IF @ActiveCount = 0
    BEGIN
        INSERT INTO dbo.ue_SMK069_shipment_api_config_mst
        (
            SiteRef, ApiName, EndpointUrl, HttpMethod, ContentType,
            AuthType, AuthHeader, AuthValue, TimeoutSeconds, IsActive,
            LoginUrl, SuccessMode, SchedulerEnabled,
            MaxBatchSize, MaxAttempts, BackoffBaseMinutes, BackoffCapMinutes
        )
        VALUES
        (
            @Site, N'SHIPMENT', @EndpointUrl, N'POST', N'application/json',
            N'BEARER_LOGIN', N'Authorization', NULL, 60, 1,
            @LoginUrl, N'KACS_V1', 0,
            50, 1440, 1, 1
        );
    END
    ELSE
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_api_config_mst
        SET EndpointUrl = @EndpointUrl,
            HttpMethod = N'POST',
            ContentType = N'application/json',
            AuthType = N'BEARER_LOGIN',
            AuthHeader = N'Authorization',
            AuthValue = NULL,
            TimeoutSeconds = 60,
            LoginUrl = @LoginUrl,
            SuccessMode = N'KACS_V1',
            SchedulerEnabled = 0,
            MaxBatchSize = 50,
            MaxAttempts = 1440,
            BackoffBaseMinutes = 1,
            BackoffCapMinutes = 1,
            UpdatedBy = SUSER_SNAME(),
            RecordDate = GETDATE()
        WHERE SiteRef = @Site
          AND ApiName = N'SHIPMENT'
          AND IsActive = 1;
    END;

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
            IntervalMinutes, MaxShipments, IsEnabled, NextRunDate
        )
        VALUES
        (
            @Site, N'HOURLY', N'Every 1 Minute',
            1, 1, 0, NULL
        );
    END
    ELSE
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_schedule_mst
        SET ScheduleName = N'Every 1 Minute',
            IntervalMinutes = 1,
            MaxShipments = 1,
            IsEnabled = 0,
            RunRequested = 0,
            LeaseUntil = NULL,
            UpdatedBy = SUSER_SNAME(),
            RecordDate = GETDATE()
        WHERE SiteRef = @Site
          AND ScheduleCode = N'HOURLY';
    END;

    COMMIT TRANSACTION;

    PRINT 'OK - PROD Shipment config prepared in SAFE OFF state.';
    PRINT 'Master SchedulerEnabled=0; HOURLY IsEnabled=0; MaxShipments=1.';
    PRINT 'No credentials were stored by this script.';
    PRINT 'Do controlled RUN ONCE before START SCHEDULER.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
