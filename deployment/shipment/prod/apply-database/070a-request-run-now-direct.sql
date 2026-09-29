/* PROD clean-baseline direct definition
   Apply Database: ONE executable batch, NO GO.
*/
ALTER PROCEDURE dbo.SMK069RequestShipmentRunNowSp
    @ScheduleCode NVARCHAR(30),
    @Success INT OUTPUT,
    @Infobar NVARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Site SiteType;
    SELECT @Site = RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0));
    EXEC SetSiteSp @Site, NULL;

    SET @Success = 0;
    SET @Infobar = NULL;
    SET @ScheduleCode = UPPER(NULLIF(LTRIM(RTRIM(@ScheduleCode)), N''));

    IF @ScheduleCode IS NULL
    BEGIN
        SET @Infobar = N'Schedule Code wajib diisi.';
        RETURN 16;
    END;

    /* SMK069-RUNONCE-BYPASS-MASTER-R1 */
    UPDATE dbo.ue_SMK069_shipment_schedule_mst
    SET RunRequested = 1,
        NextRunDate = GETDATE(),
        UpdatedBy = SUSER_SNAME(),
        RecordDate = GETDATE()
    WHERE SiteRef = @Site
      AND ScheduleCode = @ScheduleCode;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = N'Schedule tidak ditemukan.';
        RETURN 16;
    END;

    SET @Success = 1;
    SET @Infobar = CONCAT(
        N'Schedule ', @ScheduleCode,
        N' ditandai Run Now. Recurring scheduler tetap mengikuti status master/business schedule.');
    RETURN 0;
END;
