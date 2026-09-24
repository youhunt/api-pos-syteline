/* PROD migration split artifact
   Source: database/patches/shipment/2026-09-08-smk069-09-shipment-scheduler-control-center.sql
   Source batch: 9
   SyteLine Cloud Apply Database: one batch, NO GO.
*/
/* =============================================================================
   7. RESET ONE EXHAUSTED/PENDING DN AFTER OPERATOR FIXES THE CAUSE
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.SMK069ResetShipmentRetrySp
    @DN_No   NVARCHAR(40),
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
    SET @DN_No = NULLIF(LTRIM(RTRIM(@DN_No)), N'');

    IF @DN_No IS NULL
    BEGIN
        SET @Infobar = N'DN No wajib diisi.';
        RETURN 16;
    END;

    UPDATE dbo.ue_SMK069_shipment_retry_mst
    SET AttemptCount    = 0,
        RetryState      = N'P',
        NextAttemptDate = NULL,
        UpdatedBy       = SUSER_SNAME(),
        RecordDate      = GETDATE()
    WHERE SiteRef = @Site
      AND ShipmentId = @DN_No;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @Infobar = CONCAT(N'DN ', @DN_No, N' belum memiliki retry state.');
        RETURN 16;
    END;

    SET @Success = 1;
    SET @Infobar = CONCAT(
        N'DN ', @DN_No,
        N' dikembalikan ke antrean. Error terakhir tetap disimpan untuk audit.');
    RETURN 0;
END;
