/* =============================================================================
   SMK069 - Shipment Patch 16
   Fix UAT Shipment EndpointUrl and hold scheduler for controlled retry
   -----------------------------------------------------------------------------
   Date    : 2026-09-09
   Scope   : Shipment Outbound SyteLine -> POS API only

   TENANT EVIDENCE BEFORE PATCH
   ----------------------------
   Current active config:

       SiteRef          = Default
       ApiName          = SHIPMENT
       IsActive         = 1
       SchedulerEnabled = 1
       LoginUrl         = https://api-uat.pizzahut.co.id/service-auth/login-once
       EndpointUrl      = https://api-uat.pizzahut.co.id/inventory/v1/infor_dn
       HttpMethod       = POST
       ContentType      = application/json
       SuccessMode      = KACS_V1

   Current endpoint produced:

       HTTP 404
       Response=404 page not found

   Repository evidence from 7 Sep records two candidate Infor -> POS routes:

       /inventory/v1/infor_dn
       /inventory-phi/v1/infor_dn

   and records that one of those infor_dn routes reached the POS business layer
   and returned code 1010 "data is exist". Since the currently configured
   /inventory/v1/infor_dn is now proven to return route-level 404, Patch 16 moves
   UAT to the remaining evidence-backed candidate:

       https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn

   SAFETY
   ------
   * Does NOT invoke HTTP.
   * Does NOT Reset Retry.
   * Does NOT change retry counters / NextAttemptDate.
   * Sets SchedulerEnabled = 0 so P96330/P96331/P96332 cannot be consumed
     automatically before a controlled one-DN UAT.
   * Does NOT modify LoginUrl, HttpMethod, ContentType, SuccessMode, credentials,
     Shipment View, Build, Prepare, or Complete.
   * Guarded against unexpected config drift.
   * One executable Apply Database batch; NO GO.
   ============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Site NVARCHAR(8);
    DECLARE @OldEndpoint NVARCHAR(500);
    DECLARE @TargetEndpoint NVARCHAR(500);
    DECLARE @ActiveCount INT;
    DECLARE @UnexpectedCount INT;

    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));

    SET @OldEndpoint = N'https://api-uat.pizzahut.co.id/inventory/v1/infor_dn';
    SET @TargetEndpoint = N'https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn';

    SELECT @ActiveCount = COUNT(*)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    IF ISNULL(@ActiveCount, 0) <> 1
    BEGIN
        RAISERROR(
            'Patch 16 membutuhkan tepat satu config SHIPMENT aktif untuk Site saat ini. Ditemukan %d.',
            16,
            1,
            @ActiveCount
        );
    END;

    SELECT @UnexpectedCount = COUNT(*)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1
      AND ISNULL(EndpointUrl, N'') NOT IN (@OldEndpoint, @TargetEndpoint);

    IF ISNULL(@UnexpectedCount, 0) > 0
    BEGIN
        RAISERROR(
            'EndpointUrl tenant sudah berbeda dari baseline Patch 16. Patch dihentikan agar config baru tidak tertimpa.',
            16,
            1
        );
    END;

    UPDATE dbo.ue_SMK069_shipment_api_config_mst
    SET
        EndpointUrl = @TargetEndpoint,
        SchedulerEnabled = 0
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT'
      AND IsActive = 1;

    IF @@ROWCOUNT <> 1
    BEGIN
        RAISERROR('Patch 16 gagal mengubah tepat satu config SHIPMENT aktif.', 16, 1);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_api_config_mst
        WHERE SiteRef = @Site
          AND ApiName = N'SHIPMENT'
          AND IsActive = 1
          AND EndpointUrl = @TargetEndpoint
          AND ISNULL(SchedulerEnabled, 0) = 0
    )
    BEGIN
        RAISERROR('Post-assertion Patch 16 gagal: endpoint/scheduler hold tidak sesuai target.', 16, 1);
    END;

    COMMIT TRANSACTION;

    PRINT 'OK - Patch 16 applied.';
    PRINT 'EndpointUrl = https://api-uat.pizzahut.co.id/inventory-phi/v1/infor_dn';
    PRINT 'SchedulerEnabled = 0 (SAFETY HOLD).';
    PRINT 'Patch ini TIDAK melakukan HTTP call dan TIDAK Reset Retry.';
    PRINT 'Verifikasi config lalu lakukan controlled one-DN UAT sebelum scheduler diaktifkan kembali.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
