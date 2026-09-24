/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-08-shipment-scheduler-procs.sql
   Source batch: 1
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   SMK069 - Shipment Scheduler, Patch 08 (REVISI 2)
   -----------------------------------------------------------------------------
   Objects  : dbo.SMK069GetShipmentConfigSp          (NEW / ALTER)
              dbo.SMK069GetPendingShipmentsSp        (NEW / ALTER)
              dbo.SMK069RecordShipmentAttemptSp      (NEW / ALTER)
   Date     : 2026-09-08
   Design   : docs/29-shipment-scheduler.md
   Depends  : Patch 07 revision 2+

   REVISI 2 - config source corrected
   ----------------------------------
   Patch 07 revision 2 stopped creating a second config table and instead added
   scheduler columns to the existing ue_SMK069_shipment_api_config_mst.
   Revision 1 of THIS patch still referenced the discarded
   ue_SMK069_shipment_config_mst and snake_case columns. That mismatch is fixed
   here.

   The config key is now exactly the same as SMK069GetShipmentApiConfigSp:
       SiteRef + ApiName='SHIPMENT' + IsActive=1

   Nullable scheduler columns use safe effective defaults:
       SchedulerEnabled   NULL -> 0
       MaxBatchSize       NULL -> 50
       MaxAttempts        NULL -> 5
       BackoffBaseMinutes NULL -> 15
       BackoffCapMinutes  NULL -> 480
       SuccessMode        NULL -> KACS_V1

   Patch 09 additionally backfills those NULL columns for easier form display.
   ============================================================================= */

/* =============================================================================
   1. CONFIG READER
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069GetShipmentConfigSp
    @IsEnabled       INT            OUTPUT,
    @LoginUrl        NVARCHAR(500)  OUTPUT,
    @EndpointUrl     NVARCHAR(500)  OUTPUT,
    @SuccessMode     NVARCHAR(20)   OUTPUT,
    @TimeoutSeconds  INT            OUTPUT,
    @MaxBatchSize    INT            OUTPUT,
    @Infobar         NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SELECT
        @IsEnabled      = 0,
        @LoginUrl       = NULL,
        @EndpointUrl    = NULL,
        @SuccessMode    = N'KACS_V1',
        @TimeoutSeconds = 60,
        @MaxBatchSize   = 50,
        @Infobar        = NULL;

    SELECT TOP (1)
        @IsEnabled      = ISNULL(c.SchedulerEnabled, 0),
        @LoginUrl       = c.LoginUrl,
        @EndpointUrl    = c.EndpointUrl,
        @SuccessMode    = COALESCE(NULLIF(c.SuccessMode, N''), N'KACS_V1'),
        @TimeoutSeconds = COALESCE(NULLIF(c.TimeoutSeconds, 0), 60),
        @MaxBatchSize   = COALESCE(NULLIF(c.MaxBatchSize, 0), 50)
    FROM dbo.ue_SMK069_shipment_api_config_mst AS c
    WHERE c.SiteRef = @Site
      AND c.ApiName = N'SHIPMENT'
      AND c.IsActive = 1
    ORDER BY c.RecordDate DESC;

    IF @EndpointUrl IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] Konfigurasi SHIPMENT aktif untuk Site ', @Site,
            N' belum ada di ue_SMK069_shipment_api_config_mst.');
        RETURN 16;
    END;

    IF ISNULL(@IsEnabled, 0) = 0
    BEGIN
        SET @Infobar = CONCAT(
            N'Scheduler Shipment untuk Site ', @Site,
            N' dinonaktifkan (SchedulerEnabled = 0). Tidak ada yang dikirim.');
        RETURN 0;
    END;

    IF NULLIF(LTRIM(RTRIM(@LoginUrl)), N'') IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] LoginUrl Shipment untuk Site ', @Site, N' belum diisi.');
        RETURN 16;
    END;

    SET @Infobar = CONCAT(
        N'Konfigurasi Shipment Site ', @Site,
        N' aktif. Batch maksimum ', CONVERT(NVARCHAR(20), @MaxBatchSize), N'.');
    RETURN 0;
END;
