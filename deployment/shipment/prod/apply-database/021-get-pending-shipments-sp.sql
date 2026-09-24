/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-08-shipment-scheduler-procs.sql
   Source batch: 2
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
