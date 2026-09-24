/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-08-shipment-scheduler-procs.sql
   Source batch: 3
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
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
