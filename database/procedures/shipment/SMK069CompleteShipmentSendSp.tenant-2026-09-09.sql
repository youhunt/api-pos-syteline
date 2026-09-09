CREATE PROCEDURE dbo.SMK069CompleteShipmentSendSp
(
    @LogRowPointer UNIQUEIDENTIFIER,
    @HttpCode      INT,
    @ResponseJson  NVARCHAR(MAX),
    @IsSuccess     INT,
    @Success       INT OUTPUT,
    @Infobar       NVARCHAR(4000) OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- SITE CONTEXT
    ------------------------------------------------------------
    DECLARE @Site SiteType

    SELECT @Site =
        RTRIM(CONVERT(NVARCHAR(8), CONTEXT_INFO(), 0))

    EXEC SetSiteSp @Site, NULL

    ------------------------------------------------------------
    -- INITIAL OUTPUT
    ------------------------------------------------------------
    SET @Success = 0;
    SET @Infobar = NULL;

    DECLARE @ShipmentId BIGINT;

    ------------------------------------------------------------
    -- LOG HARUS BERASAL DARI SITE AKTIF
    ------------------------------------------------------------
    SELECT
        @ShipmentId = ShipmentId
    FROM dbo.ue_SMK069_shipment_api_log_mst
    WHERE SiteRef = @Site
      AND RowPointer = @LogRowPointer;

    IF @ShipmentId IS NULL
    BEGIN
        SET @Infobar =
            CONCAT(
                'Shipment API log tidak ditemukan pada Site ',
                @Site,
                '.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- SUCCESS
    ------------------------------------------------------------
    IF ISNULL(@IsSuccess, 0) = 1
    BEGIN
        UPDATE dbo.ue_SMK069_shipment_api_log_mst
        SET
            ResponseDate = GETDATE(),
            ResponseHttpCode = @HttpCode,
            ResponseJson = @ResponseJson,
            ProcessStatus = 'S',
            ErrorMessage = NULL,
            RecordDate = GETDATE(),
            UpdatedBy = SUSER_SNAME()
        WHERE SiteRef = @Site
          AND RowPointer = @LogRowPointer;

        UPDATE dbo.shipment_mst
        SET
            SMK069_Uf_api_post = 1,
            SMK069_Uf_api_post_date = GETDATE()
        WHERE site_ref = @Site
          AND shipment_id = @ShipmentId;

        SET @Success = 1;

        SET @Infobar =
            CONCAT(
                'Shipment DN ',
                CONVERT(VARCHAR(30), @ShipmentId),
                ' pada Site ',
                @Site,
                ' berhasil diposting ke POS.'
            );

        RETURN 0;
    END;

    ------------------------------------------------------------
    -- ERROR
    ------------------------------------------------------------
    UPDATE dbo.ue_SMK069_shipment_api_log_mst
    SET
        ResponseDate = GETDATE(),
        ResponseHttpCode = @HttpCode,
        ResponseJson = @ResponseJson,
        ProcessStatus = 'E',
        ErrorMessage =
            ISNULL(
                @ResponseJson,
                'API shipment gagal.'
            ),
        RetryCount =
            ISNULL(RetryCount, 0) + 1,
        RecordDate = GETDATE(),
        UpdatedBy = SUSER_SNAME()
    WHERE SiteRef = @Site
      AND RowPointer = @LogRowPointer;

    ------------------------------------------------------------
    -- TETAP PENDING
    ------------------------------------------------------------
    UPDATE dbo.shipment_mst
    SET
        SMK069_Uf_api_post = 0,
        SMK069_Uf_api_post_date = NULL
    WHERE site_ref = @Site
      AND shipment_id = @ShipmentId;

    SET @Success = 0;

    SET @Infobar =
        CONCAT(
            'Shipment DN ',
            CONVERT(VARCHAR(30), @ShipmentId),
            ' pada Site ',
            @Site,
            ' gagal dikirim ke POS.'
        );

    RETURN 0;
END;
