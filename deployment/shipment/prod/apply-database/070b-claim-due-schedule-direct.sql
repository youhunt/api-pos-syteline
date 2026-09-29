/* PROD clean-baseline direct definition
   Apply Database: ONE executable batch, NO GO.
*/
ALTER PROCEDURE dbo.SMK069ClaimDueShipmentScheduleSp
    @ScheduleCode NVARCHAR(30) OUTPUT,
    @MaxShipments INT OUTPUT,
    @HasWork INT OUTPUT,
    @Infobar NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @Site SiteType,
        @MasterEnabled INT,
        @ApiActive INT,
        @CfgMaxBatch INT;

    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SELECT
        @ScheduleCode = NULL,
        @MaxShipments = 0,
        @HasWork = 0,
        @Infobar = NULL;

    SELECT TOP (1)
        @MasterEnabled = ISNULL(SchedulerEnabled, 0),
        @ApiActive = ISNULL(IsActive, 0),
        @CfgMaxBatch = COALESCE(NULLIF(MaxBatchSize, 0), 50)
    FROM dbo.ue_SMK069_shipment_api_config_mst
    WHERE SiteRef = @Site
      AND ApiName = N'SHIPMENT';

    IF ISNULL(@ApiActive, 0) <> 1
    BEGIN
        SET @Infobar = N'API SHIPMENT tidak aktif; tidak ada schedule yang diklaim.';
        RETURN 0;
    END;

    /* SMK069-RUNONCE-CLAIM-MANUAL-R1 */

    BEGIN TRANSACTION;

    SELECT TOP (1)
        @ScheduleCode = ScheduleCode,
        @MaxShipments = COALESCE(NULLIF(MaxShipments, 0), @CfgMaxBatch, 50)
    FROM dbo.ue_SMK069_shipment_schedule_mst WITH (UPDLOCK, READPAST, ROWLOCK)
    WHERE SiteRef = @Site
      AND
      (
          RunRequested = 1
          OR
          (
              ISNULL(@MasterEnabled, 0) = 1
              AND IsEnabled = 1
              AND (NextRunDate IS NULL OR NextRunDate <= GETDATE())
          )
      )
      AND
      (
          RunState <> N'R'
          OR LeaseUntil IS NULL
          OR LeaseUntil <= GETDATE()
      )
    ORDER BY
        CASE WHEN RunRequested = 1 THEN 0 ELSE 1 END,
        NextRunDate,
        ScheduleCode;

    IF @ScheduleCode IS NOT NULL
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_schedule_mst
        SET RunRequested = 0,
            RunState = N'R',
            LeaseUntil = DATEADD(MINUTE, 15, GETDATE()),
            LastStartDate = GETDATE(),
            UpdatedBy = SUSER_SNAME(),
            RecordDate = GETDATE()
        WHERE SiteRef = @Site
          AND ScheduleCode = @ScheduleCode;

        SET @HasWork = 1;
    END;

    COMMIT TRANSACTION;

    SET @Infobar =
        CASE WHEN @HasWork = 1
            THEN CONCAT(
                N'Schedule ', @ScheduleCode,
                N' diklaim. Max Shipments=', CONVERT(NVARCHAR(20), @MaxShipments), N'.')
            WHEN ISNULL(@MasterEnabled, 0) <> 1
                THEN N'Master Shipment Scheduler OFF dan tidak ada manual RunRequested.'
            ELSE N'Tidak ada Shipment schedule yang jatuh tempo.'
        END;

    RETURN 0;
END;
