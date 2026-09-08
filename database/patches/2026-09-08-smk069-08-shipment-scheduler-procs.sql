/* =============================================================================
   SMK069 - Shipment Scheduler, Patch 08 of 08 (procedures)
   -----------------------------------------------------------------------------
   Objects  : dbo.SMK069GetShipmentConfigSp          (NEW)
              dbo.SMK069GetPendingShipmentsSp        (NEW)
              dbo.SMK069RecordShipmentAttemptSp      (NEW)
   Date     : 2026-09-08
   Design   : docs/29-shipment-scheduler.md
   Depends  : Patch 07 (config + retry tables)

   These three carry the whole scheduling policy. The extension class only does
   what SQL cannot: the HTTP call. Everything about WHICH shipments go, WHEN a
   failed one is tried again, and WHEN to give up lives here, so the policy can
   be changed by an operator without a code deployment.

   OUTPUT PARAMETERS, NOT RESULT SETS
   ----------------------------------
   The pending list comes back as a delimited string in an OUTPUT parameter
   rather than a result set. Context.Commands.Invoke in the extension class
   reads output parameters cleanly; consuming a result set through the same path
   is far more awkward. The list is bounded by max_batch_size, so it stays small.

   ALL SITE-AWARE
   --------------
   Every procedure resolves the active Site from CONTEXT_INFO() and scopes every
   read and write to it, per the 3 Sep hardening standard.
   ============================================================================= */

/* =============================================================================
   1. CONFIG READER
      One call so the extension class does not need to know the table.
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

    SET @IsEnabled      = 0;
    SET @LoginUrl       = NULL;
    SET @EndpointUrl    = NULL;
    SET @SuccessMode    = NULL;
    SET @TimeoutSeconds = 0;
    SET @MaxBatchSize   = 0;
    SET @Infobar        = NULL;

    SELECT TOP (1)
        @IsEnabled      = c.is_enabled,
        @LoginUrl       = c.login_url,
        @EndpointUrl    = c.endpoint_url,
        @SuccessMode    = c.success_mode,
        @TimeoutSeconds = c.timeout_seconds,
        @MaxBatchSize   = c.max_batch_size
    FROM dbo.ue_SMK069_shipment_config_mst AS c
    WHERE c.SiteRef = @Site;

    IF @EndpointUrl IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] Konfigurasi Shipment untuk Site ', @Site,
            N' belum ada di ue_SMK069_shipment_config_mst.');
        RETURN 16;
    END;

    IF ISNULL(@IsEnabled, 0) = 0
    BEGIN
        SET @Infobar = CONCAT(
            N'Scheduler Shipment untuk Site ', @Site,
            N' dinonaktifkan (is_enabled = 0). Tidak ada yang dikirim.');
        RETURN 0;
    END;

    SET @Infobar = CONCAT(
        N'Konfigurasi Site ', @Site,
        N' aktif. Batch maksimum ', CONVERT(NVARCHAR(20), @MaxBatchSize), N'.');

    RETURN 0;
END;
GO

/* =============================================================================
   2. PENDING PICKER
      A shipment is due when it is unposted, has real quantity, and either has
      never been attempted or its backoff has elapsed. Exhausted shipments are
      excluded - that is the whole point of the attempt budget.
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069GetPendingShipmentsSp
    @MaxRows       INT            = NULL,
    @PendingList   NVARCHAR(MAX)  OUTPUT,   -- comma separated DN numbers
    @PendingCount  INT            OUTPUT,
    @DueLaterCount INT            OUTPUT,   -- waiting out a backoff
    @ExhaustedCount INT           OUTPUT,   -- gave up, needs an operator
    @Infobar       NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @PendingList    = NULL;
    SET @PendingCount   = 0;
    SET @DueLaterCount  = 0;
    SET @ExhaustedCount = 0;
    SET @Infobar        = NULL;

    DECLARE @MaxAttempts INT, @CfgBatch INT;

    SELECT TOP (1)
        @MaxAttempts = c.max_attempts,
        @CfgBatch    = c.max_batch_size
    FROM dbo.ue_SMK069_shipment_config_mst AS c
    WHERE c.SiteRef = @Site;

    IF @MaxAttempts IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] Konfigurasi Shipment untuk Site ', @Site, N' belum ada.');
        RETURN 16;
    END;

    SET @MaxRows = COALESCE(NULLIF(@MaxRows, 0), @CfgBatch, 50);

    /* Every unposted shipment on this Site, one row per DN. */
    SELECT DISTINCT
        LTRIM(RTRIM(CONVERT(NVARCHAR(30), v.DN_No))) AS ShipmentId
    INTO #Candidate
    FROM dbo.SMK069_ShipmentAPI_mst AS v
    WHERE v.site_ref = @Site
      AND ISNULL(v.Api_post, 0) = 0
      AND ISNULL(v.shipment_qty, 0) > 0
      AND NULLIF(LTRIM(RTRIM(CONVERT(NVARCHAR(30), v.DN_No))), N'') IS NOT NULL;

    SELECT
        c.ShipmentId,
        ISNULL(r.attempt_count, 0) AS attempt_count,
        r.next_attempt_date,
        ISNULL(r.retry_state, N'P') AS retry_state
    INTO #Scored
    FROM #Candidate AS c
    LEFT JOIN dbo.ue_SMK069_shipment_retry_mst AS r
           ON r.SiteRef = @Site
          AND r.ShipmentId = c.ShipmentId;

    SELECT @ExhaustedCount = COUNT(*)
    FROM #Scored
    WHERE retry_state = N'X' OR attempt_count >= @MaxAttempts;

    SELECT @DueLaterCount = COUNT(*)
    FROM #Scored
    WHERE retry_state = N'P'
      AND attempt_count < @MaxAttempts
      AND next_attempt_date IS NOT NULL
      AND next_attempt_date > GETDATE();

    ;WITH Due AS
    (
        SELECT TOP (@MaxRows) ShipmentId
        FROM #Scored
        WHERE retry_state = N'P'
          AND attempt_count < @MaxAttempts
          AND (next_attempt_date IS NULL OR next_attempt_date <= GETDATE())
        ORDER BY
            attempt_count ASC,              -- fresh shipments before retries
            next_attempt_date ASC,
            ShipmentId ASC
    )
    SELECT
        @PendingList =
            STUFF
            (
                (
                    SELECT N',' + d.ShipmentId
                    FROM Due AS d
                    ORDER BY d.ShipmentId
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
      Called once per shipment, after Complete. Owns the backoff arithmetic and
      the decision to give up.

      Backoff is base * 2^(attempt-1), capped:
          base 15  ->  15, 30, 60, 120, 240 minutes
      Only failures are delayed. A success clears the schedule.
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069RecordShipmentAttemptSp
    @DN_No           NVARCHAR(30),
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
    SET @AttemptCount    = 0;
    SET @NextAttemptDate = NULL;
    SET @Exhausted       = 0;
    SET @Infobar         = NULL;

    IF @DN_No IS NULL
    BEGIN
        SET @Infobar = N'[POS-901] DN_No wajib diisi.';
        RETURN 16;
    END;

    DECLARE
        @MaxAttempts INT,
        @BaseMin     INT,
        @CapMin      INT;

    SELECT TOP (1)
        @MaxAttempts = c.max_attempts,
        @BaseMin     = c.backoff_base_minutes,
        @CapMin      = c.backoff_cap_minutes
    FROM dbo.ue_SMK069_shipment_config_mst AS c
    WHERE c.SiteRef = @Site;

    IF @MaxAttempts IS NULL
    BEGIN
        SET @Infobar = CONCAT(
            N'[POS-901] Konfigurasi Shipment untuk Site ', @Site, N' belum ada.');
        RETURN 16;
    END;

    /* Make sure a state row exists before updating it. */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ue_SMK069_shipment_retry_mst
        WHERE SiteRef = @Site AND ShipmentId = @DN_No
    )
    BEGIN
        INSERT INTO dbo.ue_SMK069_shipment_retry_mst
            (SiteRef, ShipmentId, attempt_count, retry_state)
        VALUES
            (@Site, @DN_No, 0, N'P');
    END;

    /* ---------------------------------------------------------------- success */
    IF ISNULL(@IsSuccess, 0) = 1
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_retry_mst
        SET attempt_count      = attempt_count + 1,
            retry_state        = N'S',
            first_attempt_date = COALESCE(first_attempt_date, GETDATE()),
            last_attempt_date  = GETDATE(),
            next_attempt_date  = NULL,
            last_http_code     = @HttpCode,
            last_error         = NULL,
            UpdatedBy          = SUSER_SNAME(),
            RecordDate         = GETDATE()
        WHERE SiteRef = @Site AND ShipmentId = @DN_No;

        SELECT @AttemptCount = attempt_count
        FROM dbo.ue_SMK069_shipment_retry_mst
        WHERE SiteRef = @Site AND ShipmentId = @DN_No;

        SET @Infobar = CONCAT(
            N'DN ', @DN_No, N' terkirim pada percobaan ke-',
            CONVERT(NVARCHAR(20), @AttemptCount), N'.');

        RETURN 0;
    END;

    /* ---------------------------------------------------------------- failure */
    DECLARE @NewCount INT, @DelayMin INT;

    SELECT @NewCount = attempt_count + 1
    FROM dbo.ue_SMK069_shipment_retry_mst
    WHERE SiteRef = @Site AND ShipmentId = @DN_No;

    /* base * 2^(attempt-1), guarded against overflow and capped */
    SET @DelayMin =
        CASE
            WHEN @NewCount >= 20 THEN @CapMin
            ELSE
                CASE
                    WHEN @BaseMin * POWER(CONVERT(BIGINT, 2), @NewCount - 1) > @CapMin
                    THEN @CapMin
                    ELSE CONVERT(INT, @BaseMin * POWER(CONVERT(BIGINT, 2), @NewCount - 1))
                END
        END;

    SET @Exhausted = CASE WHEN @NewCount >= @MaxAttempts THEN 1 ELSE 0 END;

    UPDATE dbo.ue_SMK069_shipment_retry_mst
    SET attempt_count      = @NewCount,
        retry_state        = CASE WHEN @Exhausted = 1 THEN N'X' ELSE N'P' END,
        first_attempt_date = COALESCE(first_attempt_date, GETDATE()),
        last_attempt_date  = GETDATE(),
        next_attempt_date  = CASE
                                 WHEN @Exhausted = 1 THEN NULL
                                 ELSE DATEADD(MINUTE, @DelayMin, GETDATE())
                             END,
        last_http_code     = @HttpCode,
        last_error         = LEFT(@ErrorMessage, 1000),
        UpdatedBy          = SUSER_SNAME(),
        RecordDate         = GETDATE()
    WHERE SiteRef = @Site AND ShipmentId = @DN_No;

    SELECT
        @AttemptCount    = attempt_count,
        @NextAttemptDate = next_attempt_date
    FROM dbo.ue_SMK069_shipment_retry_mst
    WHERE SiteRef = @Site AND ShipmentId = @DN_No;

    SET @Infobar =
        CASE
            WHEN @Exhausted = 1
            THEN CONCAT(
                N'DN ', @DN_No, N' gagal ', CONVERT(NVARCHAR(20), @AttemptCount),
                N' kali dan tidak akan dicoba lagi otomatis. ',
                N'Perbaiki penyebabnya lalu reset retry_state ke P. ',
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
   OPERATOR QUERIES
   ============================================================================= */
/*
-- apa yang sedang menunggu, dan kenapa
SELECT r.ShipmentId, r.retry_state, r.attempt_count,
       r.next_attempt_date, r.last_http_code, LEFT(r.last_error, 200) AS last_error
FROM dbo.ue_SMK069_shipment_retry_mst AS r
WHERE r.SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND r.retry_state <> N'S'
ORDER BY r.retry_state DESC, r.next_attempt_date;

-- kembalikan satu DN yang sudah menyerah ke antrean, setelah penyebabnya dibereskan
UPDATE dbo.ue_SMK069_shipment_retry_mst
SET retry_state = N'P', attempt_count = 0, next_attempt_date = NULL,
    UpdatedBy = SUSER_SNAME(), RecordDate = GETDATE()
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))
  AND ShipmentId = N'P96325';

-- hidupkan scheduler setelah UAT lulus
UPDATE dbo.ue_SMK069_shipment_config_mst
SET is_enabled = 1, UpdatedBy = SUSER_SNAME(), RecordDate = GETDATE()
WHERE SiteRef = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
*/
