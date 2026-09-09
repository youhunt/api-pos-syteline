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
GO

/* =============================================================================
   2. PENDING PICKER
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069GetPendingShipmentsSp
    @MaxRows        INT            = NULL,
    @PendingList    NVARCHAR(MAX)  OUTPUT,
    @PendingCount   INT            OUTPUT,
    @DueLaterCount  INT            OUTPUT,
    @ExhaustedCount INT            OUTPUT,
    @Infobar        NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SELECT
        @PendingList    = NULL,
        @PendingCount   = 0,
        @DueLaterCount  = 0,
        @ExhaustedCount = 0,
        @Infobar        = NULL;

    DECLARE
        @MaxAttempts INT,
        @CfgBatch INT;

    SELECT TOP (1)
        @MaxAttempts = COALESCE(NULLIF(c.MaxAttempts, 0), 5),
        @CfgBatch    = COALESCE(NULLIF(c.MaxBatchSize, 0), 50)
    FROM dbo.ue_SMK069_shipment_api_config_mst AS c
    WHERE c.SiteRef = @Site
      AND c.ApiName = N'SHIPMENT'
      AND c.IsActive = 1
    ORDER BY c.RecordDate DESC;

    IF @MaxAttempts IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] Konfigurasi SHIPMENT aktif untuk Site ', @Site, N' belum ada.');
        RETURN 16;
    END;

    SET @MaxRows = COALESCE(NULLIF(@MaxRows, 0), @CfgBatch, 50);

    SELECT DISTINCT
        LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))) AS ShipmentId
    INTO #Candidate
    FROM dbo.SMK069_ShipmentAPI_mst AS v
    WHERE v.site_ref = @Site
      AND ISNULL(v.Api_post, 0) = 0
      AND ISNULL(v.shipment_qty, 0) > 0
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(40), v.DN_No))), N'') IS NOT NULL;

    SELECT
        c.ShipmentId,
        ISNULL(r.AttemptCount, 0) AS AttemptCount,
        r.NextAttemptDate,
        ISNULL(r.RetryState, N'P') AS RetryState
    INTO #Scored
    FROM #Candidate AS c
    LEFT JOIN dbo.ue_SMK069_shipment_retry_mst AS r
      ON r.SiteRef = @Site
     AND r.ShipmentId = c.ShipmentId;

    SELECT @ExhaustedCount = COUNT(*)
    FROM #Scored
    WHERE RetryState = N'X'
       OR AttemptCount >= @MaxAttempts;

    SELECT @DueLaterCount = COUNT(*)
    FROM #Scored
    WHERE RetryState = N'P'
      AND AttemptCount < @MaxAttempts
      AND NextAttemptDate IS NOT NULL
      AND NextAttemptDate > GETDATE();

    ;WITH Due AS
    (
        SELECT TOP (@MaxRows)
            ShipmentId,
            AttemptCount,
            NextAttemptDate
        FROM #Scored
        WHERE RetryState = N'P'
          AND AttemptCount < @MaxAttempts
          AND (NextAttemptDate IS NULL OR NextAttemptDate <= GETDATE())
        ORDER BY
            AttemptCount ASC,
            NextAttemptDate ASC,
            ShipmentId ASC
    )
    SELECT
        @PendingList =
            STUFF
            (
                (
                    SELECT N',' + d.ShipmentId
                    FROM Due AS d
                    ORDER BY d.AttemptCount, d.NextAttemptDate, d.ShipmentId
                    FOR XML PATH(N''), TYPE
                ).value(N'.', N'NVARCHAR(MAX)'),
                1, 1, N''
            );

    SET @PendingCount =
        CASE
            WHEN NULLIF(@PendingList, N'') IS NULL THEN 0
            ELSE LEN(@PendingList) - LEN(REPLACE(@PendingList, N',', N'')) + 1
        END;

    SET @Infobar = CONCAT(
        N'Site ', @Site,
        N': siap kirim ', CONVERT(NVARCHAR(20), @PendingCount),
        N'; menunggu backoff ', CONVERT(NVARCHAR(20), @DueLaterCount),
        N'; berhenti dicoba ', CONVERT(NVARCHAR(20), @ExhaustedCount), N'.');

    DROP TABLE #Scored;
    DROP TABLE #Candidate;

    RETURN 0;
END;
GO

/* =============================================================================
   3. ATTEMPT RECORDER
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069RecordShipmentAttemptSp
    @DN_No           NVARCHAR(40),
    @IsSuccess       INT,
    @HttpCode        INT            = NULL,
    @ErrorMessage    NVARCHAR(1000) = NULL,
    @AttemptCount    INT            OUTPUT,
    @NextAttemptDate DATETIME       OUTPUT,
    @Exhausted       INT            OUTPUT,
    @Infobar         NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @DN_No = NULLIF(LTRIM(RTRIM(@DN_No)), N'');

    SELECT
        @AttemptCount    = 0,
        @NextAttemptDate = NULL,
        @Exhausted       = 0,
        @Infobar         = NULL;

    IF @DN_No IS NULL
    BEGIN
        SET @Infobar = N'[POS-901] DN_No wajib diisi.';
        RETURN 16;
    END;

    DECLARE
        @MaxAttempts INT,
        @BaseMin INT,
        @CapMin INT;

    SELECT TOP (1)
        @MaxAttempts = COALESCE(NULLIF(c.MaxAttempts, 0), 5),
        @BaseMin     = COALESCE(NULLIF(c.BackoffBaseMinutes, 0), 15),
        @CapMin      = COALESCE(NULLIF(c.BackoffCapMinutes, 0), 480)
    FROM dbo.ue_SMK069_shipment_api_config_mst AS c
    WHERE c.SiteRef = @Site
      AND c.ApiName = N'SHIPMENT'
      AND c.IsActive = 1
    ORDER BY c.RecordDate DESC;

    IF @MaxAttempts IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] Konfigurasi SHIPMENT aktif untuk Site ', @Site, N' belum ada.');
        RETURN 16;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ue_SMK069_shipment_retry_mst
        WHERE SiteRef = @Site
          AND ShipmentId = @DN_No
    )
    BEGIN
        INSERT INTO dbo.ue_SMK069_shipment_retry_mst
            (SiteRef, ShipmentId, AttemptCount, RetryState)
        VALUES
            (@Site, @DN_No, 0, N'P');
    END;

    IF ISNULL(@IsSuccess, 0) = 1
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_retry_mst
        SET AttemptCount     = AttemptCount + 1,
            RetryState       = N'S',
            FirstAttemptDate = COALESCE(FirstAttemptDate, GETDATE()),
            LastAttemptDate  = GETDATE(),
            NextAttemptDate  = NULL,
            LastHttpCode     = @HttpCode,
            LastError        = NULL,
            UpdatedBy        = SUSER_SNAME(),
            RecordDate       = GETDATE()
        WHERE SiteRef = @Site
          AND ShipmentId = @DN_No;

        SELECT @AttemptCount = AttemptCount
        FROM dbo.ue_SMK069_shipment_retry_mst
        WHERE SiteRef = @Site
          AND ShipmentId = @DN_No;

        SET @Infobar = CONCAT(
            N'DN ', @DN_No, N' terkirim pada percobaan ke-',
            CONVERT(NVARCHAR(20), @AttemptCount), N'.');
        RETURN 0;
    END;

    DECLARE
        @NewCount INT,
        @DelayBig BIGINT,
        @DelayMin INT;

    SELECT @NewCount = AttemptCount + 1
    FROM dbo.ue_SMK069_shipment_retry_mst
    WHERE SiteRef = @Site
      AND ShipmentId = @DN_No;

    SET @DelayBig =
        CASE
            WHEN @NewCount >= 20 THEN CONVERT(BIGINT, @CapMin)
            ELSE CONVERT(BIGINT, @BaseMin)
                 * POWER(CONVERT(BIGINT, 2), @NewCount - 1)
        END;

    SET @DelayMin =
        CASE
            WHEN @DelayBig > @CapMin THEN @CapMin
            ELSE CONVERT(INT, @DelayBig)
        END;

    SET @Exhausted = CASE WHEN @NewCount >= @MaxAttempts THEN 1 ELSE 0 END;

    UPDATE dbo.ue_SMK069_shipment_retry_mst
    SET AttemptCount     = @NewCount,
        RetryState       = CASE WHEN @Exhausted = 1 THEN N'X' ELSE N'P' END,
        FirstAttemptDate = COALESCE(FirstAttemptDate, GETDATE()),
        LastAttemptDate  = GETDATE(),
        NextAttemptDate  =
            CASE
                WHEN @Exhausted = 1 THEN NULL
                ELSE DATEADD(MINUTE, @DelayMin, GETDATE())
            END,
        LastHttpCode = @HttpCode,
        LastError    = LEFT(@ErrorMessage, 1000),
        UpdatedBy    = SUSER_SNAME(),
        RecordDate   = GETDATE()
    WHERE SiteRef = @Site
      AND ShipmentId = @DN_No;

    SELECT
        @AttemptCount    = AttemptCount,
        @NextAttemptDate = NextAttemptDate
    FROM dbo.ue_SMK069_shipment_retry_mst
    WHERE SiteRef = @Site
      AND ShipmentId = @DN_No;

    SET @Infobar =
        CASE
            WHEN @Exhausted = 1
            THEN CONCAT(
                N'DN ', @DN_No, N' gagal ', CONVERT(NVARCHAR(20), @AttemptCount),
                N' kali dan tidak akan dicoba lagi otomatis. ',
                N'Perbaiki penyebabnya lalu gunakan Reset Retry pada form. ',
                COALESCE(LEFT(@ErrorMessage, 500), N''))
            ELSE CONCAT(
                N'DN ', @DN_No, N' gagal pada percobaan ke-',
                CONVERT(NVARCHAR(20), @AttemptCount),
                N'. Dicoba lagi paling cepat ',
                CONVERT(NVARCHAR(30), @NextAttemptDate, 120), N'. ',
                COALESCE(LEFT(@ErrorMessage, 500), N''))
        END;

    RETURN 0;
END;
GO

/* =============================================================================
   VERIFICATION
   ============================================================================= */
/*
DECLARE
    @IsEnabled INT, @LoginUrl NVARCHAR(500), @EndpointUrl NVARCHAR(500),
    @SuccessMode NVARCHAR(20), @TimeoutSeconds INT, @MaxBatchSize INT,
    @Infobar NVARCHAR(4000);

EXEC dbo.SMK069GetShipmentConfigSp
     @IsEnabled OUTPUT, @LoginUrl OUTPUT, @EndpointUrl OUTPUT,
     @SuccessMode OUTPUT, @TimeoutSeconds OUTPUT, @MaxBatchSize OUTPUT,
     @Infobar OUTPUT;

SELECT @IsEnabled AS IsEnabled, @LoginUrl AS LoginUrl,
       @EndpointUrl AS EndpointUrl, @SuccessMode AS SuccessMode,
       @TimeoutSeconds AS TimeoutSeconds, @MaxBatchSize AS MaxBatchSize,
       @Infobar AS Infobar;

DECLARE
    @PendingList NVARCHAR(MAX), @PendingCount INT,
    @DueLaterCount INT, @ExhaustedCount INT, @PendingInfobar NVARCHAR(4000);

EXEC dbo.SMK069GetPendingShipmentsSp
     NULL, @PendingList OUTPUT, @PendingCount OUTPUT,
     @DueLaterCount OUTPUT, @ExhaustedCount OUTPUT, @PendingInfobar OUTPUT;

SELECT @PendingList AS PendingList, @PendingCount AS PendingCount,
       @DueLaterCount AS DueLaterCount, @ExhaustedCount AS ExhaustedCount,
       @PendingInfobar AS Infobar;
*/
